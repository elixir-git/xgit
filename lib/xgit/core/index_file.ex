defmodule Xgit.Core.IndexFile do
  @moduledoc ~S"""
  The index file records the current (intended) contents of a working tree
  when last scanned or created by git.

  In Xgit, the `IndexFile` structure is an abstract, in-memory data structure
  without any tie to a specific persistence mechanism. Persistence is implemented
  by a specific implementation of the `Xgit.Repository` behaviour.

  Changes in the working tree can be detected by comparing the modification times
  to the cached modification time within the index file.

  Index files are also used during merges, where the merge happens within the
  index file first, and the working directory is updated as a post-merge step.
  Conflicts are stored in the index file to allow tool (and human) based
  resolutions to be easily performed.
  """

  use Bitwise
  use Xgit.Core.FileMode

  alias Xgit.Util.NB

  @typedoc ~S"""
  Version number for an index file.
  """
  @type version :: 2..4

  @typedoc ~S"""
  This struct describes an entire working tree as understood by git.

  ## Struct Members

  * `:version`: the version number as read from disk (typically 2, 3, or 4)
  * `:entry_count`: the number of items in `entries`
  * `:entries`: a list of `Entry` structs in sorted order
  * `:extensions`: a list of `Extension` structs (not yet implemented)
  """
  @type t :: %__MODULE__{
          version: version,
          entry_count: non_neg_integer,
          entries: [__MODULE__.Entry.t()]
          # extensions: [Extention.t()]
        }

  @enforce_keys [:version, :entry_count, :entries]
  defstruct [:version, :entry_count, :entries]

  defmodule Entry do
    @moduledoc ~S"""
    A single file (or stage of a file) in an index file.

    An entry represents exactly one stage of a file. If a file path is unmerged
    then multiple instances may appear for the same path name.
    """

    alias Xgit.Core.FileMode
    alias Xgit.Core.ObjectId

    @typedoc ~S"""
    A single file (or stage of a file) in an index file.

    An entry represents exactly one stage of a file. If a file path is unmerged
    then multiple instances may appear for the same path name.

    Consult the [documentation for git index file format](https://github.com/git/git/blob/master/Documentation/technical/index-format.txt)
    for a more detailed description of each item.

    ## Struct Members

    * `name`: entry path name, relative to top-level directory (without leading slash)
    * `stage`: 0..3 merge status
    * `object_id`: (ObjectId.t) SHA-1 for the represented object
    * `mode`: (FileMode.t)
    * `size`: (integer) on-disk size, possibly truncated to 32 bits
    * `ctime`: (integer) the last time the file's metadata changed
    * `ctime_ns`: (integer) nanosecond fraction of `ctime` (if available)
    * `mtime`: (integer) the last time a file's contents changed
    * `mtime_ns`: (integer) nanosecond fractino of `mtime` (if available)
    * `dev`: (integer)
    * `ino`: (integer)
    * `uid`: (integer)
    * `gid`: (integer)
    * `assume_valid?`: (boolean)
    * `extended?`: (boolean)
    * `skip_worktree?`: (boolean)
    * `intent_to_add?`: (boolean)
    """
    @type t :: %__MODULE__{
            name: charlist,
            stage: 0..3,
            object_id: ObjectId.t(),
            mode: FileMode.t(),
            size: non_neg_integer,
            ctime: integer,
            ctime_ns: non_neg_integer,
            mtime: integer,
            mtime_ns: non_neg_integer,
            dev: integer,
            ino: integer,
            uid: integer,
            gid: integer,
            assume_valid?: boolean,
            extended?: boolean,
            skip_worktree?: boolean,
            intent_to_add?: boolean
          }

    @enforce_keys [:name, :stage, :object_id, :size, :mode, :ctime, :mtime]

    defstruct [
      :name,
      :stage,
      :object_id,
      :size,
      :mode,
      :ctime,
      :mtime,
      ctime_ns: 0,
      mtime_ns: 0,
      dev: 0,
      ino: 0,
      uid: 0,
      gid: 0,
      assume_valid?: false,
      extended?: false,
      skip_worktree?: false,
      intent_to_add?: false
    ]
  end

  @typedoc ~S"""
  Error codes which can be returned by `from_iodevice/1`.
  """
  @type from_iodevice_reason :: :invalid_format | :unsupported_version

  @doc ~S"""
  Read index file from an `IO.device` (typically an opened file) and returns a
  corresponding `IndexFile` struct.

  ## Return Value

  `{:ok, index_file}` if the iodevice contains a valid index file.

  `{:error, :invalid_format}` if the iodevice can not be parsed as an index file.

  `{:error, :unsupported_version}` if the index file is not a version 2 index file.
  Other versions are not supported at this time.
  """
  @spec from_iodevice(iodevice :: IO.device()) ::
          {:ok, index_file :: t} | {:error, reason :: from_iodevice_reason}
  def from_iodevice(iodevice) do
    with {:dirc, true} <- {:dirc, read_dirc(iodevice)},
         {:version, version = 2} <- {:version, read_uint32(iodevice)},
         {:entry_count, entry_count} when is_integer(entry_count) <-
           {:entry_count, read_uint32(iodevice)},
         {:entries, entries} when is_list(entries) <-
           {:entries, read_entries(iodevice, version, entry_count)} do
      {:ok,
       %__MODULE__{
         version: version,
         entry_count: entry_count,
         entries: entries
       }}
    else
      {:dirc, _} -> {:error, :invalid_format}
      {:version, _} -> {:error, :unsupported_version}
      {:entries, _} -> {:error, :invalid_format}
    end
  end

  defp read_dirc(iodevice) do
    case IO.binread(iodevice, 4) do
      "DIRC" -> true
      _ -> false
    end
  end

  defp read_entries(_iodevice, _version, 0 = _entry_count), do: []

  defp read_entries(iodevice, version, entry_count) do
    entries =
      Enum.map(1..entry_count, fn i ->
        read_entry(iodevice, version, i == 1)
      end)

    if Enum.all?(entries, &valid_entry?/1),
      do: entries,
      else: :invalid
  end

  defp read_entry(iodevice, 2 = _version, first?) do
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
         object_id when is_binary(object_id) <- read_object_id(iodevice),
         flags when is_integer(flags) <- read_uint16(iodevice),
         name when is_list(name) <- read_name(iodevice, flags &&& 0xFFF, first?) do
      %__MODULE__.Entry{
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

  defp valid_entry?(%__MODULE__.Entry{}), do: true
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

  defp read_name(iodevice, length, first?) when length < 0xFFF do
    first_shift = if first?, do: 4, else: 0
    bytes_to_read = length + padding(Integer.mod(length + first_shift, 8))

    case IO.binread(iodevice, bytes_to_read) do
      x when is_binary(x) and byte_size(x) == bytes_to_read ->
        x
        |> :binary.bin_to_list()
        |> Enum.take_while(&(&1 != 0))

      _ ->
        :invalid
    end
  end

  defp padding(length_mod_8) when length_mod_8 < 6, do: 6 - length_mod_8
  defp padding(6), do: 8
  defp padding(7), do: 7

  defp to_boolean(0), do: false
  defp to_boolean(_), do: true
end
