defmodule Xgit.Repository.WorkingTree.WriteIndexFile do
  @moduledoc ~S"""
  Save an `Xgit.Core.DirCache` to the corresponding git `index` file data structure.
  """

  use Bitwise
  use Xgit.Core.FileMode

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry, as: DirCacheEntry
  alias Xgit.Core.ObjectId
  alias Xgit.Util.NB
  alias Xgit.Util.TrailingHashDevice

  @typedoc ~S"""
  Error codes which can be returned by `to_iodevice/1`.
  """
  @type to_iodevice_reason ::
          :not_sha_hash_device | :invalid_dir_cache | :unsupported_version | File.posix()

  @doc ~S"""
  Write index file to an `iodevice` (typically an opened file) from an
  `Xgit.Core.DirCache` struct.

  _IMPORTANT:_ The `iodevice` must be created using `Xgit.Util.TrailingHashDevice`.

  ## Return Value

  `:ok` if written successfully.

  `{:error, :not_sha_hash_device}` if the iodevice was not created using
  `Xgit.Util.TrailingHashDevice`.

  `{:error, :invalid_dir_cache}` if `Xgit.Core.DirCache.valid?/1` does not return
  `true` for this struct.

  `{:error, :unsupported_version}` if the `version` flag in the dir cache struct
  is not version. Other versions are not supported at this time.

  `{:error, posix_reason}` if an I/O error occurs.
  """
  @spec to_iodevice(dir_cache :: DirCache.t(), iodevice :: IO.device()) ::
          :ok | {:error, reason :: to_iodevice_reason}
  def to_iodevice(
        %DirCache{version: version, entry_count: entry_count, entries: entries} = dir_cache,
        iodevice
      ) do
    with {:version, 2} <- {:version, version},
         {:valid?, true} <- {:valid?, DirCache.valid?(dir_cache)},
         {:sha_hash_device, true} <- {:sha_hash_device, TrailingHashDevice.valid?(iodevice)},
         :ok <- write_v2_header(iodevice, entry_count),
         :ok <- write_v2_entries(iodevice, entries) do
      # TO DO: Write extensions. https://github.com/elixir-git/xgit/issues/114
      cover :ok
    else
      {:version, _} -> cover {:error, :unsupported_version}
      {:valid?, _} -> cover {:error, :invalid_dir_cache}
      {:sha_hash_device, _} -> cover {:error, :not_sha_hash_device}
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp write_v2_header(iodevice, entry_count),
    do: IO.binwrite(iodevice, ['DIRC', 0, 0, 0, 2, NB.encode_uint32(entry_count)])

  defp write_v2_entries(_iodevice, []), do: cover(:ok)

  defp write_v2_entries(iodevice, [entry | tail]) do
    case write_v2_entry(iodevice, entry) do
      :ok -> write_v2_entries(iodevice, tail)
      error -> error
    end
  end

  defp write_v2_entry(
         iodevice,
         %DirCacheEntry{
           name: name,
           stage: stage,
           object_id: object_id,
           size: size,
           mode: mode,
           ctime: ctime,
           ctime_ns: ctime_ns,
           mtime: mtime,
           mtime_ns: mtime_ns,
           dev: dev,
           ino: ino,
           uid: uid,
           gid: gid,
           assume_valid?: assume_valid?,
           extended?: extended?,
           skip_worktree?: false,
           intent_to_add?: false
         }
       ) do
    name_length = Enum.count(name)

    IO.binwrite(iodevice, [
      NB.encode_uint32(ctime),
      NB.encode_uint32(ctime_ns),
      NB.encode_uint32(mtime),
      NB.encode_uint32(mtime_ns),
      NB.encode_uint32(dev),
      NB.encode_uint32(ino),
      NB.encode_uint32(mode),
      NB.encode_uint32(uid),
      NB.encode_uint32(gid),
      NB.encode_uint32(size),
      ObjectId.to_binary_iodata(object_id),
      encode_v2_flags(stage, assume_valid?, extended?, name_length),
      name,
      padding(name_length)
    ])
  end

  defp encode_v2_flags(stage, assume_valid?, extended?, name_length) do
    value =
      value_if_boolean(assume_valid?, 0x8000) +
        value_if_boolean(extended?, 0x4000) +
        bsl(stage &&& 3, 12) +
        min(name_length, 0xFFF)

    NB.encode_uint16(value)
  end

  defp value_if_boolean(true, value), do: value
  defp value_if_boolean(false, _value), do: cover(0)

  defp padding(name_length) do
    padding_size = padding_size(Integer.mod(name_length + 4, 8))
    Enum.map(1..padding_size, fn _ -> 0 end)
  end

  defp padding_size(length_mod_8) when length_mod_8 < 6, do: 6 - length_mod_8
  defp padding_size(6), do: cover(8)
  defp padding_size(7), do: cover(7)
end
