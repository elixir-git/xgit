defmodule Xgit.Core.DirCache do
  @moduledoc ~S"""
  A directory cache records the current (intended) contents of a working tree
  when last scanned or created by git.

  In Xgit, the `DirCache` structure is an abstract, in-memory data structure
  without any tie to a specific persistence mechanism. Persistence is implemented
  by a specific implementation of the `Xgit.Repository` behaviour.

  This content is commonly persisted on disk as an `index` file at the root of
  the git tree. The module `Xgit.Repository.WorkingTree.ParseIndexFile` can
  parse that file format.

  Changes in the working tree can be detected by comparing the modification times
  to the cached modification time within the dir cache.

  Index files are also used during merges, where the merge happens within the
  index file first, and the working directory is updated as a post-merge step.
  Conflicts are stored in the index file to allow tool (and human) based
  resolutions to be easily performed.
  """

  use Bitwise
  use Xgit.Core.FileMode

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

    use Xgit.Core.FileMode

    alias Xgit.Core.ObjectId

    @typedoc ~S"""
    A single file (or stage of a file) in a directory cache.

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
            name: [byte],
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

    alias Xgit.Core.FileMode
    alias Xgit.Core.ObjectId
    alias Xgit.Core.ValidatePath

    @doc ~S"""
    Return `true` if this entry struct describes a valid dir cache entry.
    """
    @spec valid?(entry :: any) :: boolean
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
      ValidatePath.check_path(name) == :ok && ObjectId.valid?(object_id) &&
        object_id != ObjectId.zero()
    end

    def valid?(_), do: false

    @doc ~S"""
    Compare two entries according to git dir cache entry sort ordering rules.

    For this purpose, only the following fields are considered (in this priority order):

    * `:name`
    * `:mode`
    * `:stage`

    ## Return Value

    * `:lt` if `entry1` sorts before `entry2`.
    * `:eq` if they are the same.
    * `:gt` if `entry1` sorts after `entry2`.
    """
    @spec compare(entry1 :: t | nil, entry2 :: t) :: :lt | :eq | :gt
    def compare(entry1, entry2)

    def compare(nil, _entry2), do: :lt

    def compare(
          %{name: name1, mode: mode1, stage: stage1} = _entry1,
          %{name: name2, mode: mode2, stage: stage2} = _entry2
        ) do
      cond do
        name1 < name2 -> :lt
        name2 < name1 -> :gt
        mode1 < mode2 -> :lt
        mode2 < mode1 -> :gt
        stage1 < stage2 -> :lt
        stage2 < stage1 -> :gt
        true -> :eq
      end
    end
  end

  @doc ~S"""
  Return `true` if this entry struct describes a valid dir cache.
  """
  @spec valid?(dir_cache :: any) :: boolean
  def valid?(%__MODULE__{version: version, entry_count: entry_count, entries: entries})
      when version == 2 and is_integer(entry_count) and is_list(entries) do
    Enum.count(entries) == entry_count &&
      Enum.all?(entries, &Entry.valid?/1) &&
      entries_sorted?([nil | entries])
  end

  def valid?(_), do: false

  defp entries_sorted?([entry1, entry2 | tail]),
    do: Entry.compare(entry1, entry2) == :lt && entries_sorted?([entry2 | tail])

  defp entries_sorted?([_]), do: true
end
