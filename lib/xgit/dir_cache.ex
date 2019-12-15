defmodule Xgit.DirCache do
  @moduledoc ~S"""
  A directory cache records the current (intended) contents of a working tree
  when last scanned or created by git.

  In Xgit, the `DirCache` structure is an abstract, in-memory data structure
  without any tie to a specific persistence mechanism. Persistence is implemented
  by a specific implementation of the `Xgit.Repository.Storage` behaviour.

  This content is commonly persisted on disk as an `index` file at the root of
  the git tree. This file format can be read using the `from_iodevice/1` function
  and written using `to_iodevice/1`. If a different persistence mechanism is
  required, you may provide that e elsewhere.

  Changes in the working tree can be detected by comparing the modification times
  to the cached modification time within the dir cache.

  Index files are also used during merges, where the merge happens within the
  index file first, and the working directory is updated as a post-merge step.
  Conflicts are stored in the index file to allow tool (and human) based
  resolutions to be easily performed.
  """

  use Bitwise
  use Xgit.FileMode

  import Xgit.Util.ForceCoverage

  require Logger

  alias Xgit.FilePath
  alias Xgit.ObjectId
  alias Xgit.Tree
  alias Xgit.Util.Comparison
  alias Xgit.Util.NB
  alias Xgit.Util.TrailingHashDevice

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
          # extensions: [Extension.t()]
        }

  @enforce_keys [:version, :entry_count, :entries]
  defstruct [:version, :entry_count, :entries]

  defmodule Entry do
    @moduledoc ~S"""
    A single file (or stage of a file) in a directory cache.

    An entry represents exactly one stage of a file. If a file path is unmerged
    then multiple instances may appear for the same path name.
    """

    use Xgit.FileMode

    alias Xgit.FileMode
    alias Xgit.FilePath
    alias Xgit.ObjectId

    @typedoc ~S"""
    Merge status (stage).
    """
    @type stage :: 0..3

    @typedoc ~S"""
    Merge status (stage) for matching a remove request. (Includes `:all` to match any stage.)
    """
    @type stage_match :: 0..3 | :all

    @typedoc ~S"""
    A single file (or stage of a file) in a directory cache.

    An entry represents exactly one stage of a file. If a file path is unmerged
    then multiple instances may appear for the same path name.

    Consult the [documentation for git index file format](https://github.com/git/git/blob/master/Documentation/technical/index-format.txt)
    for a more detailed description of each item.

    ## Struct Members

    * `name`: (`FilePath.t`) entry path name, relative to top-level directory (without leading slash)
    * `stage`: (`0..3`) merge status
    * `object_id`: (`ObjectId.t`) SHA-1 for the represented object
    * `mode`: (`FileMode.t`)
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
            name: FilePath.t(),
            stage: stage,
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

    @doc ~S"""
    Return `true` if this entry struct describes a valid dir cache entry.
    """
    @spec valid?(entry :: any) :: boolean
    def valid?(entry)

    # credo:disable-for-lines:30 Credo.Check.Refactor.CyclomaticComplexity
    def valid?(
          %__MODULE__{
            name: name,
            stage: stage,
            object_id: object_id,
            mode: mode,
            size: size,
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
            skip_worktree?: skip_worktree?,
            intent_to_add?: intent_to_add?
          } = _entry
        )
        when is_list(name) and is_integer(stage) and stage >= 0 and stage <= 3 and
               is_binary(object_id) and
               is_file_mode(mode) and
               is_integer(size) and
               size >= 0 and
               is_integer(ctime) and
               is_integer(ctime_ns) and ctime_ns >= 0 and
               is_integer(mtime) and
               is_integer(mtime_ns) and mtime_ns >= 0 and
               is_integer(dev) and
               is_integer(ino) and
               is_integer(uid) and
               is_integer(gid) and
               is_boolean(assume_valid?) and
               is_boolean(extended?) and
               is_boolean(skip_worktree?) and
               is_boolean(intent_to_add?) do
      FilePath.valid?(name) && ObjectId.valid?(object_id) && object_id != ObjectId.zero()
    end

    def valid?(_), do: cover(false)

    @doc ~S"""
    Compare two entries according to git dir cache entry sort ordering rules.

    For this purpose, only the following fields are considered (in this priority order):

    * `:name`
    * `:stage`

    ## Return Value

    * `:lt` if `entry1` sorts before `entry2`.
    * `:eq` if they are the same.
    * `:gt` if `entry1` sorts after `entry2`.
    """
    @spec compare(entry1 :: t | nil, entry2 :: t) :: Comparison.result()
    def compare(entry1, entry2)

    def compare(nil, _entry2), do: cover(:lt)

    def compare(
          %{name: name1, stage: stage1} = _entry1,
          %{name: name2, stage: stage2} = _entry2
        ) do
      cond do
        name1 < name2 -> cover :lt
        name2 < name1 -> cover :gt
        stage1 < stage2 -> cover :lt
        stage2 < stage1 -> cover :gt
        true -> cover :eq
      end
    end
  end

  @doc ~S"""
  Returns a dir cache that is the canonical "empty" dir cache (i.e. contains no entries).
  """
  @spec empty() :: t
  def empty, do: %__MODULE__{version: 2, entry_count: 0, entries: []}

  @doc ~S"""
  Return `true` if the value is a `DirCache` struct that is valid.

  All of the following must be true for this to occur:
  * The value is a `DirCache` struct.
  * The version is supported by Xgit. (Currently, only version 2 is supported.)
  * The `entry_count` matches the actual number of entries.
  * The entries are properly sorted.
  * All entries are valid, as determined by `Xgit.DirCache.Entry.valid?/1`.
  """
  @spec valid?(dir_cache :: any) :: boolean
  def valid?(dir_cache)

  def valid?(%__MODULE__{version: version, entry_count: entry_count, entries: entries})
      when version == 2 and is_integer(entry_count) and is_list(entries) do
    Enum.count(entries) == entry_count &&
      Enum.all?(entries, &Entry.valid?/1) &&
      entries_sorted?([nil | entries])
  end

  def valid?(_), do: cover(false)

  defp entries_sorted?([entry1, entry2 | tail]) do
    Entry.compare(entry1, entry2) == :lt &&
      (entry1 == nil ||
         not FilePath.starts_with?(entry2.name, FilePath.ensure_trailing_separator(entry1.name))) &&
      entries_sorted?([entry2 | tail])
  end

  defp entries_sorted?([_]), do: cover(true)

  @doc ~S"""
  Return `true` if all of the entries in this dir cache are fully merged (stage 0).
  """
  @spec fully_merged?(dir_cache :: t) :: boolean
  def fully_merged?(%__MODULE__{entries: entries} = _dir_cache) do
    Enum.all?(entries, fn %__MODULE__.Entry{stage: stage} -> stage == 0 end)
  end

  @typedoc ~S"""
  Error reason codes returned by `add_entries/2`.
  """
  @type add_entries_reason :: :invalid_dir_cache | :invalid_entries | :duplicate_entries

  @doc ~S"""
  Returns a dir cache that has new directory entries added in.

  In the event of a collision between entries (same path and stage), the existing
  entry will be replaced by the new one.

  ## Parameters

  `entries` a list of entries to add to the existing dir cache

  ## Return Value

  `{:ok, dir_cache}` where `dir_cache` is the original `dir_cache` with the new
  entries added (and properly sorted).

  `{:error, :invalid_dir_cache}` if the original `dir_cache` was invalid.

  `{:error, :invalid_entries}` if one or more of the entries is invalid.

  `{:error, :duplicate_entries}` if one or more of the entries in the _new_ list
  are duplicates of other entries in the _new_ list. (As stated earlier, duplicates
  from the original list are acceptable; in that event, the new entry will replace
  the old one.)
  """
  @spec add_entries(dir_cache :: t, new_entries :: [Entry.t()]) ::
          {:ok, t} | {:error, add_entries_reason}
  def add_entries(%__MODULE__{entries: existing_entries} = dir_cache, new_entries)
      when is_list(new_entries) do
    with {:dir_cache_valid?, true} <- {:dir_cache_valid?, valid?(dir_cache)},
         {:entries_valid?, true} <- {:entries_valid?, Enum.all?(new_entries, &Entry.valid?/1)},
         sorted_new_entries <- Enum.sort_by(new_entries, &{&1.name, &1.stage}),
         {:duplicates, ^sorted_new_entries} <-
           {:duplicates, Enum.dedup_by(sorted_new_entries, &{&1.name, &1.stage})} do
      combined_entries = combine_entries(existing_entries, sorted_new_entries)

      cover {:ok,
             %{dir_cache | entry_count: Enum.count(combined_entries), entries: combined_entries}}
    else
      {:dir_cache_valid?, _} -> cover {:error, :invalid_dir_cache}
      {:entries_valid?, _} -> cover {:error, :invalid_entries}
      {:duplicates, _} -> cover {:error, :duplicate_entries}
    end
  end

  defp combine_entries(existing_entries, sorted_new_entries)

  defp combine_entries(existing_entries, []), do: cover(existing_entries)
  defp combine_entries([], sorted_new_entries), do: cover(sorted_new_entries)

  defp combine_entries(
         [existing_head | existing_tail] = existing_entries,
         [new_head | new_tail] = sorted_new_entries
       ) do
    case Entry.compare(existing_head, new_head) do
      :lt -> cover [existing_head | combine_entries(existing_tail, sorted_new_entries)]
      :eq -> cover [new_head | combine_entries(existing_tail, new_tail)]
      :gt -> cover [new_head | combine_entries(existing_entries, new_tail)]
    end
  end

  @typedoc ~S"""
  An entry for the `remove` option for `remove_entries/2`.
  """
  @type entry_to_remove :: {path :: FilePath.t(), stage :: Entry.stage_match()}

  @typedoc ~S"""
  Error reason codes returned by `remove_entries/2`.
  """
  @type remove_entries_reason :: :invalid_dir_cache | :invalid_entries

  @doc ~S"""
  Returns a dir cache that has some directory entries removed.

  ## Parameters

  `entries_to_remove` is a list of `{path, stage}` tuples identifying tuples to be removed.

  * `path` should be a byte list for the path.
  * `stage` should be `0..3` or `:all`, meaning any entry that matches the path,
    regardless of stage, should be removed.

  ## Return Value

  `{:ok, dir_cache}` where `dir_cache` is the original `dir_cache` with any matching
  entries removed.

  `{:error, :invalid_dir_cache}` if the original `dir_cache` was invalid.

  `{:error, :invalid_entries}` if one or more of the entries is invalid.
  """
  @spec remove_entries(dir_cache :: t, entries_to_remove :: [entry_to_remove]) ::
          {:ok, t} | {:error, remove_entries_reason}
  def remove_entries(%__MODULE__{entries: existing_entries} = dir_cache, entries_to_remove)
      when is_list(entries_to_remove) do
    with {:dir_cache_valid?, true} <- {:dir_cache_valid?, valid?(dir_cache)},
         {:entries_valid?, true} <-
           {:entries_valid?, Enum.all?(entries_to_remove, &valid_remove_entry?/1)} do
      updated_entries = remove_matching_entries(existing_entries, Enum.sort(entries_to_remove))

      cover {:ok,
             %{dir_cache | entry_count: Enum.count(updated_entries), entries: updated_entries}}
    else
      {:dir_cache_valid?, _} -> cover {:error, :invalid_dir_cache}
      {:entries_valid?, _} -> cover {:error, :invalid_entries}
    end
  end

  defp valid_remove_entry?({path, :all}) when is_list(path), do: cover(true)

  defp valid_remove_entry?({path, stage})
       when is_list(path) and is_integer(stage) and stage >= 0 and stage <= 3,
       do: cover(true)

  defp valid_remove_entry?(_), do: cover(false)

  defp remove_matching_entries(sorted_existing_entries, sorted_entries_to_remove)

  defp remove_matching_entries([], _sorted_entries_to_remove), do: cover([])
  defp remove_matching_entries(sorted_existing_entries, []), do: cover(sorted_existing_entries)

  defp remove_matching_entries([%__MODULE__.Entry{name: path} | existing_tail], [
         {path, :all} | remove_tail
       ]),
       do:
         remove_matching_entries(Enum.drop_while(existing_tail, &(&1.name == path)), remove_tail)

  defp remove_matching_entries([%__MODULE__.Entry{name: path, stage: stage} | existing_tail], [
         {path, stage} | remove_tail
       ]),
       do: remove_matching_entries(existing_tail, remove_tail)

  defp remove_matching_entries([existing_head | existing_tail], sorted_entries_to_remove),
    do: cover([existing_head | remove_matching_entries(existing_tail, sorted_entries_to_remove)])

  @typedoc ~S"""
  Error reason codes returned by `to_tree_objects/2`.
  """
  @type to_tree_objects_reason :: :invalid_dir_cache | :prefix_not_found

  @doc ~S"""
  Convert this `DirCache` to one or more `tree` objects.

  ## Parameters

  `prefix`: (`Xgit.FilePath`) if present, return the object ID for the tree
  pointed to by `prefix`. All tree objects will be generated, regardless of `prefix`.

  ## Return Value

  `{:ok, objects, prefix_tree}` where `objects` is a list of `Xgit.Object`
  structs of type `tree`. All others must be written or must be present in the
  object database for the top-level tree to be valid. `prefix_tree` is the
  tree for the subtree specified by `prefix` or the top-level tree if no prefix
  was specified.

  `{:error, :invalid_dir_cache}` if the `DirCache` is not valid.

  `{:error, :prefix_not_found}` if no tree matching `prefix` exists.
  """
  @spec to_tree_objects(dir_cache :: t, prefix :: Xgit.FilePath.t()) ::
          {:ok, [Xgit.Object.t()], Xgit.Object.t()} | {:error, to_tree_objects_reason}
  def to_tree_objects(dir_cache, prefix \\ [])

  def to_tree_objects(%__MODULE__{entries: entries} = dir_cache, prefix)
      when is_list(entries) and is_list(prefix) do
    with {:valid?, true} <- {:valid?, valid?(dir_cache)},
         {_entries, tree_for_prefix, _this_tree} <- to_tree_objects_inner(entries, [], %{}, []),
         {:prefix, prefix_tree} when prefix_tree != nil <-
           {:prefix, Map.get(tree_for_prefix, FilePath.ensure_trailing_separator(prefix))} do
      objects =
        tree_for_prefix
        |> Enum.sort()
        |> Enum.map(fn {_prefix, object} -> object end)

      cover {:ok, objects, prefix_tree}
    else
      {:valid?, _} -> cover {:error, :invalid_dir_cache}
      {:prefix, _} -> cover {:error, :prefix_not_found}
    end
  end

  defp to_tree_objects_inner(entries, prefix, tree_for_prefix, tree_entries_acc)

  defp to_tree_objects_inner([], prefix, tree_for_prefix, tree_entries_acc),
    do: make_tree_and_continue([], prefix, tree_for_prefix, tree_entries_acc)

  defp to_tree_objects_inner(
         [%__MODULE__.Entry{name: name, object_id: object_id, mode: mode} | tail] = entries,
         prefix,
         tree_for_prefix,
         tree_entries_acc
       ) do
    if FilePath.starts_with?(name, prefix) do
      name_after_prefix = Enum.drop(name, Enum.count(prefix))

      {next_entries, new_tree_entry, tree_for_prefix} =
        if Enum.any?(name_after_prefix, &(&1 == ?/)) do
          make_subtree(entries, prefix, tree_for_prefix, tree_entries_acc)
        else
          cover {tail, %Tree.Entry{name: name_after_prefix, object_id: object_id, mode: mode},
                 tree_for_prefix}
        end

      to_tree_objects_inner(next_entries, prefix, tree_for_prefix, [
        new_tree_entry | tree_entries_acc
      ])
    else
      make_tree_and_continue(entries, prefix, tree_for_prefix, tree_entries_acc)
    end
  end

  defp make_tree_and_continue(entries, prefix, tree_for_prefix, tree_entries_acc) do
    tree_object = Tree.to_object(%Tree{entries: Enum.reverse(tree_entries_acc)})
    {entries, Map.put(tree_for_prefix, prefix, tree_object), tree_object}
  end

  defp make_subtree(
         [%__MODULE__.Entry{name: name} | _tail] = entries,
         existing_prefix,
         tree_for_prefix,
         _tree_entries_acc
       ) do
    first_segment_after_prefix =
      name
      |> Enum.drop(Enum.count(existing_prefix))
      |> Enum.drop_while(&(&1 == ?/))
      |> Enum.take_while(&(&1 != ?/))

    tree_name =
      cover '#{FilePath.ensure_trailing_separator(existing_prefix)}#{first_segment_after_prefix}'

    new_prefix = cover '#{tree_name}/'

    {entries, tree_for_prefix, tree_object} =
      to_tree_objects_inner(entries, new_prefix, tree_for_prefix, [])

    new_tree_entry = %Tree.Entry{
      name: first_segment_after_prefix,
      object_id: tree_object.id,
      mode: FileMode.tree()
    }

    cover {entries, new_tree_entry, tree_for_prefix}
  end

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
  Read a git `index` file from an `IO.device` (typically an opened file) and returns a
  corresponding `DirCache` struct.

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
          {:ok, dir_cache :: t()} | {:error, reason :: from_iodevice_reason}
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
             %__MODULE__{
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
      _ -> cover :invalid
    end
  end

  defp valid_entry?(%__MODULE__.Entry{}), do: cover(true)
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
    bytes_to_read = length + padding_size(Integer.mod(length + 4, 8))

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

  defp padding_size(length_mod_8) when length_mod_8 < 6, do: 6 - length_mod_8
  defp padding_size(6), do: cover(8)
  defp padding_size(7), do: cover(7)

  defp to_boolean(0), do: cover(false)
  defp to_boolean(_), do: cover(true)

  @typedoc ~S"""
  Error codes which can be returned by `to_iodevice/1`.
  """
  @type to_iodevice_reason ::
          :not_sha_hash_device | :invalid_dir_cache | :unsupported_version | File.posix()

  @doc ~S"""
  Write index file to an `iodevice` (typically an opened file) from a
  `DirCache` struct.

  _IMPORTANT:_ The `iodevice` must be created using `Xgit.Util.TrailingHashDevice`.

  ## Return Value

  `:ok` if written successfully.

  `{:error, :not_sha_hash_device}` if the iodevice was not created using
  `Xgit.Util.TrailingHashDevice`.

  `{:error, :invalid_dir_cache}` if `valid?/1` does not return
  `true` for this struct.

  `{:error, :unsupported_version}` if the `version` flag in the dir cache struct
  is not version. Other versions are not supported at this time.

  `{:error, posix_reason}` if an I/O error occurs.
  """
  @spec to_iodevice(dir_cache :: t(), iodevice :: IO.device()) ::
          :ok | {:error, reason :: to_iodevice_reason}
  def to_iodevice(
        %__MODULE__{version: version, entry_count: entry_count, entries: entries} = dir_cache,
        iodevice
      ) do
    with {:version, 2} <- {:version, version},
         {:valid?, true} <- {:valid?, valid?(dir_cache)},
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
         %__MODULE__.Entry{
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
end
