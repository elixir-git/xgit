defmodule Xgit.Repository.WorkingTree.ParseIndexFile do
  @moduledoc ~S"""
  Parse a git `index` file and turn it into a corresponding `Xgit.Core.DirCache`
  structure.
  """

  use Bitwise
  use Xgit.Core.FileMode

  import Xgit.Util.ForceCoverage

  require Logger

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry, as: DirCacheEntry
  alias Xgit.Core.ObjectId
  alias Xgit.Util.NB
  alias Xgit.Util.TrailingHashDevice

  @typedoc ~S"""
  Error codes which can be returned by `from_iodevice/1`.
  """
  @type from_iodevice_reason ::
          :not_sha_hash_device
          | :invalid_format
          | :unsupported_version
          | :too_many_entries
          | :unsupported_extension
          | :sha_hash_mismatch
          | File.posix()

  @doc ~S"""
  Read index file from an `IO.device` (typically an opened file) and returns a
  corresponding `Xgit.Core.DirCache` struct.

  _IMPORTANT:_ The `IO.device` must be created using `Xgit.Util.TrailingHashDevice`.

  ## Return Value

  `{:ok, dir_cache}` if the iodevice contains a valid index file.

  `{:error, :not_sha_hash_device}` if the iodevice was not created using
  `Xgit.Util.TrailingHashDevice`.

  `{:error, :invalid_format}` if the iodevice can not be parsed as an index file.

  `{:error, :unsupported_version}` if the index file is not a version 2 index file.
  Other versions are not supported at this time.

  `{:error, :too_many_entries}` if the index files contains more than 100,000
  entries. This is an arbitrary limit to guard against malformed files and to
  prevent overconsumption of memory. With experience, it could be revisited.

  `{:error, :unsupported_extension}` if any index file extensions are present
  that can not be parsed. Optional extensions will be skipped, but no required
  extensions are understood at this time. (See
  [issue #172](https://github.com/elixir-git/xgit/issues/172).)

  `{:error, :sha_hash_mismatch}` if the SHA-1 hash written at the end of the file
  does not match the file contents.
  """
  @spec from_iodevice(iodevice :: IO.device()) ::
          {:ok, dir_cache :: DirCache.t()} | {:error, reason :: from_iodevice_reason}
  def from_iodevice(iodevice) do
    with {:sha_hash_device, true} <- {:sha_hash_device, TrailingHashDevice.valid?(iodevice)},
         {:dirc, true} <- {:dirc, read_dirc(iodevice)},
         {:version, version = 2} <- {:version, read_uint32(iodevice)},
         {:entry_count, entry_count}
         when is_integer(entry_count) and entry_count <= 100_000 <-
           {:entry_count, read_uint32(iodevice)},
         {:entries, entries} when is_list(entries) <-
           {:entries, read_entries(iodevice, version, entry_count)},
         {:extensions, :ok} <- {:extensions, read_extensions(iodevice)},
         {:sha_valid?, true} <- {:sha_valid?, TrailingHashDevice.valid_hash?(iodevice)} do
      cover {:ok,
             %DirCache{
               version: version,
               entry_count: entry_count,
               entries: entries
             }}
    else
      {:sha_hash_device, _} -> cover {:error, :not_sha_hash_device}
      {:dirc, _} -> cover {:error, :invalid_format}
      {:version, _} -> cover {:error, :unsupported_version}
      {:entry_count, :invalid} -> cover {:error, :invalid_format}
      {:entry_count, _} -> cover {:error, :too_many_entries}
      {:entries, _} -> cover {:error, :invalid_format}
      {:extensions, error} -> cover {:error, error}
      {:sha_valid?, _} -> cover {:error, :sha_hash_mismatch}
    end
  end

  defp read_dirc(iodevice) do
    case IO.binread(iodevice, 4) do
      "DIRC" -> cover true
      _ -> cover false
    end
  end

  defp read_entries(_iodevice, _version, 0), do: cover([])

  defp read_entries(iodevice, version, entry_count) do
    entries =
      Enum.map(1..entry_count, fn _ ->
        read_entry(iodevice, version)
      end)

    if Enum.all?(entries, &valid_entry?/1) do
      cover entries
    else
      cover :invalid
    end
  end

  defp read_entry(iodevice, 2 = _version) do
    with ctime when is_integer(ctime) <- read_uint32(iodevice),
         ctime_ns when is_integer(ctime_ns) <- read_uint32(iodevice),
         mtime when is_integer(mtime) <- read_uint32(iodevice),
         mtime_ns when is_integer(mtime_ns) <- read_uint32(iodevice),
         dev when is_integer(dev) <- read_uint32(iodevice),
         ino when is_integer(ino) <- read_uint32(iodevice),
         mode when is_integer(mode) <- read_uint32(iodevice),
         uid when is_integer(uid) <- read_uint32(iodevice),
         gid when is_integer(gid) <- read_uint32(iodevice),
         size when is_integer(size) <- read_uint32(iodevice),
         object_id
         when is_binary(object_id) and object_id != "0000000000000000000000000000000000000000" <-
           read_object_id(iodevice),
         flags when is_integer(flags) and flags > 0 <- read_uint16(iodevice),
         name when is_list(name) <- read_name(iodevice, flags &&& 0xFFF) do
      %DirCacheEntry{
        name: name,
        stage: bsr(flags &&& 0x3000, 12),
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
        assume_valid?: to_boolean(flags &&& 0x8000),
        extended?: to_boolean(flags &&& 0x4000),
        skip_worktree?: false,
        intent_to_add?: false
      }
    else
      _ -> cover :invalid
    end
  end

  defp valid_entry?(%DirCacheEntry{}), do: cover(true)
  defp valid_entry?(_), do: cover(false)

  defp read_extensions(iodevice) do
    case IO.binread(iodevice, 1) do
      :eof ->
        :ok

      char when byte_size(char) == 1 and char >= "A" and char <= "Z" ->
        read_optional_extension(iodevice, char)

      char ->
        read_required_extension(iodevice, char)
    end
  end

  defp read_optional_extension(iodevice, char) do
    signature = "#{char}#{IO.binread(iodevice, 3)}"
    length = read_uint32(iodevice)

    Logger.info(fn ->
      "skipping extension with signature #{inspect(signature)}, #{length} bytes"
    end)

    IO.binread(iodevice, length)
    read_extensions(iodevice)
  end

  defp read_required_extension(iodevice, char) do
    signature = "#{char}#{IO.binread(iodevice, 3)}"
    length = read_uint32(iodevice)

    Logger.info(fn ->
      "don't know how to read required extension with signature #{inspect(signature)}, #{length} bytes"
    end)

    :unsupported_extension
  end

  defp read_uint16(iodevice) do
    case IO.binread(iodevice, 2) do
      x when is_binary(x) and byte_size(x) == 2 ->
        x
        |> :binary.bin_to_list()
        |> NB.decode_uint16()
        |> elem(0)

      _ ->
        cover :invalid
    end
  end

  defp read_uint32(iodevice) do
    case IO.binread(iodevice, 4) do
      x when is_binary(x) and byte_size(x) == 4 ->
        x
        |> :binary.bin_to_list()
        |> NB.decode_uint32()
        |> elem(0)

      _ ->
        cover :invalid
    end
  end

  defp read_object_id(iodevice) do
    case IO.binread(iodevice, 20) do
      x when is_binary(x) and byte_size(x) == 20 -> ObjectId.from_binary_iodata(x)
      _ -> cover :invalid
    end
  end

  defp read_name(iodevice, length) when length < 0xFFF do
    bytes_to_read = length + padding(Integer.mod(length + 4, 8))

    case IO.binread(iodevice, bytes_to_read) do
      x when is_binary(x) and byte_size(x) == bytes_to_read ->
        x
        |> :binary.bin_to_list()
        |> Enum.take_while(&(&1 != 0))

      _ ->
        cover :invalid
    end
  end

  defp read_name(_iodevice, _length), do: :invalid

  defp padding(length_mod_8) when length_mod_8 < 6, do: 6 - length_mod_8
  defp padding(6), do: cover(8)
  defp padding(7), do: cover(7)

  defp to_boolean(0), do: cover(false)
  defp to_boolean(_), do: cover(true)
end
