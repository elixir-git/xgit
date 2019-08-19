defmodule Xgit.Repository.WorkingTree.ParseIndexFile do
  @moduledoc ~S"""
  Parse a git `index` file and turn it into a corresponding `Xgit.Core.DirCache`
  structure.
  """

  use Bitwise
  use Xgit.Core.FileMode

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry, as: DirCacheEntry
  alias Xgit.Util.NB

  @typedoc ~S"""
  Error codes which can be returned by `from_iodevice/1`.
  """
  @type from_iodevice_reason :: :invalid_format | :unsupported_version | :too_many_entries

  @doc ~S"""
  Read index file from an `IO.device` (typically an opened file) and returns a
  corresponding `Xgit.Core.DirCache` struct.

  ## Return Value

  `{:ok, dir_cache}` if the iodevice contains a valid index file.

  `{:error, :invalid_format}` if the iodevice can not be parsed as an index file.

  `{:error, :unsupported_version}` if the index file is not a version 2 index file.
  Other versions are not supported at this time.

  `{:error, :too_many_entries}` if the index files contains more than 100,000
  entries. This is an arbitrary limit to guard against malformed files and to
  prevent overconsumption of memory. With experience, it could be revisited.
  """
  @spec from_iodevice(iodevice :: IO.device()) ::
          {:ok, dir_cache :: DirCache.t()} | {:error, reason :: from_iodevice_reason}
  def from_iodevice(iodevice) do
    with {:dirc, true} <- {:dirc, read_dirc(iodevice)},
         {:version, version = 2} <- {:version, read_uint32(iodevice)},
         {:entry_count, entry_count}
         when is_integer(entry_count) and entry_count <= 100_000 <-
           {:entry_count, read_uint32(iodevice)},
         {:entries, entries} when is_list(entries) <-
           {:entries, read_entries(iodevice, version, entry_count)} do
      # TO DO: Parse extensions and trailing checksum.
      # https://github.com/elixir-git/xgit/issues/67

      {:ok,
       %DirCache{
         version: version,
         entry_count: entry_count,
         entries: entries
       }}
    else
      {:dirc, _} -> {:error, :invalid_format}
      {:version, _} -> {:error, :unsupported_version}
      {:entry_count, :invalid} -> {:error, :invalid_format}
      {:entry_count, _} -> {:error, :too_many_entries}
      {:entries, _} -> {:error, :invalid_format}
    end
  end

  defp read_dirc(iodevice) do
    case IO.binread(iodevice, 4) do
      "DIRC" -> true
      _ -> false
    end
  end

  defp read_entries(_iodevice, _version, 0), do: []

  defp read_entries(iodevice, version, entry_count) do
    entries =
      Enum.map(1..entry_count, fn _ ->
        read_entry(iodevice, version)
      end)

    if Enum.all?(entries, &valid_entry?/1),
      do: entries,
      else: :invalid
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
      _ -> :invalid
    end
  end

  defp valid_entry?(%DirCacheEntry{}), do: true
  defp valid_entry?(_), do: false

  defp read_uint16(iodevice) do
    case IO.binread(iodevice, 2) do
      x when is_binary(x) and byte_size(x) == 2 ->
        x
        |> :binary.bin_to_list()
        |> NB.decode_uint16()
        |> elem(0)

      _ ->
        :invalid
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
        :invalid
    end
  end

  defp read_object_id(iodevice) do
    case IO.binread(iodevice, 20) do
      x when is_binary(x) and byte_size(x) == 20 ->
        x
        |> Base.encode16()
        |> String.downcase()

      _ ->
        :invalid
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
        :invalid
    end
  end

  defp read_name(_iodevice, _length), do: :invalid

  defp padding(length_mod_8) when length_mod_8 < 6, do: 6 - length_mod_8
  defp padding(6), do: 8
  defp padding(7), do: 7

  defp to_boolean(0), do: false
  defp to_boolean(_), do: true
end
