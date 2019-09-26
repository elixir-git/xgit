defmodule Xgit.Repository.WorkingTree do
  @moduledoc ~S"""
  A working tree is an on-disk manifestation of a commit or pending commit in
  a git repository.

  An `Xgit.Repository` may have a default working tree associated with it or
  it may not. (Such a repository is often referred to as a "bare" repository.)

  More than one working tree may be associated with a repository, though this
  is not (currently) well-tested in Xgit.

  A working tree is itself strictly tied to a file system, but it need not be
  tied to an on-disk repository instance.

  _IMPORTANT NOTE:_ This is intended as a reference implementation largely
  for testing purposes and may not necessarily handle all of the edge cases that
  the traditional `git` command-line interface will handle.
  """
  use GenServer

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry, as: DirCacheEntry
  alias Xgit.Core.FilePath
  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Core.Tree
  alias Xgit.Repository
  alias Xgit.Repository.WorkingTree.ParseIndexFile
  alias Xgit.Repository.WorkingTree.WriteIndexFile
  alias Xgit.Util.TrailingHashDevice

  require Logger

  @typedoc ~S"""
  The process ID for a `WorkingTree` process.
  """
  @type t :: pid

  @doc """
  Starts a `WorkingTree` process linked to the current process.

  ## Parameters

  `repository` is the associated `Xgit.Repository` process.

  `work_dir` is the root path for the working tree.

  `options` are passed to `GenServer.start_link/3`.

  ## Return Value

  See `GenServer.start_link/3`.

  If the process is unable to create the working directory root, the response
  will be `{:error, {:mkdir, :eexist}}` (or perhaps a different posix error code).
  """
  @spec start_link(repository :: Repository.t(), work_dir :: Path.t(), GenServer.options()) ::
          GenServer.on_start()
  def start_link(repository, work_dir, options \\ [])
      when is_pid(repository) and is_binary(work_dir) and is_list(options) do
    if Repository.valid?(repository) do
      GenServer.start_link(__MODULE__, {repository, work_dir}, options)
    else
      cover {:error, :invalid_repository}
    end
  end

  @impl true
  def init({repository, work_dir}) do
    case File.mkdir_p(work_dir) do
      :ok ->
        index_path = Path.join([work_dir, ".git", "index"])

        Process.monitor(repository)
        # Read index file here or maybe in a :continue handler?

        cover {:ok, %{repository: repository, work_dir: work_dir, index_path: index_path}}

      {:error, reason} ->
        cover {:stop, {:mkdir, reason}}
    end
  end

  @doc ~S"""
  Returns `true` if the argument is a PID representing a valid `WorkingTree` process.
  """
  @spec valid?(working_tree :: term) :: boolean
  def valid?(working_tree) when is_pid(working_tree) do
    Process.alive?(working_tree) &&
      GenServer.call(working_tree, :valid_working_tree?) == :valid_working_tree
  end

  def valid?(_), do: cover(false)

  @doc ~S"""
  Returns a current snapshot of the working tree state.

  ## Return Value

  `{:ok, dir_cache}` if an index file exists and could be parsed as a dir cache file.

  `{:ok, dir_cache}` if no index file exists. (`dir_cache` will have zero entries.)

  `{:error, reason}` if the file exists but could not be parsed.

  See `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1` for possible
  reason codes.

  ## TO DO

  Find index file in appropriate location (i.e. as potentially modified
  by `.git/config` file). [Issue #86](https://github.com/elixir-git/xgit/issues/86)

  Cache state of index file so we don't have to parse it for every
  call. [Issue #87](https://github.com/elixir-git/xgit/issues/87)

  Consider scalability of passing a potentially large `Xgit.Core.DirCache` structure
  across process boundaries. [Issue #88](https://github.com/elixir-git/xgit/issues/88)
  """
  @spec dir_cache(working_tree :: t) ::
          {:ok, DirCache.t()} | {:error, reason :: ParseIndexFile.from_iodevice_reason()}
  def dir_cache(working_tree) when is_pid(working_tree),
    do: GenServer.call(working_tree, :dir_cache)

  defp handle_dir_cache(%{index_path: index_path} = state) do
    case parse_index_file_if_exists(index_path) do
      {:ok, dir_cache} -> {:reply, {:ok, dir_cache}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @typedoc ~S"""
  Error code reasons returned by `reset_dir_cache/1`.
  """
  @type reset_dir_cache_reason :: WriteIndexFile.to_iodevice_reason()

  @doc ~S"""
  Reset the dir cache to empty and rewrite the index file accordingly.

  ## Return Values

  `:ok` if successful.

  `{:error, reason}` if unable. The relevant reason codes may come from:

  * `Xgit.Repository.WorkingTree.WriteIndexFile.to_iodevice/2`.
  """
  @spec reset_dir_cache(working_tree :: t) ::
          :ok | {:error, reset_dir_cache_reason}
  def reset_dir_cache(working_tree) when is_pid(working_tree),
    do: GenServer.call(working_tree, :reset_dir_cache)

  defp handle_reset_dir_cache(%{index_path: index_path} = state) do
    case write_index_file(DirCache.empty(), index_path) do
      :ok -> cover {:reply, :ok, state}
      {:error, reason} -> cover {:reply, {:error, reason}, state}
    end
  end

  @typedoc ~S"""
  Error code reasons returned by `update_dir_cache/3`.
  """
  @type update_dir_cache_reason ::
          DirCache.add_entries_reason()
          | DirCache.remove_entries_reason()
          | ParseIndexFile.from_iodevice_reason()
          | WriteIndexFile.to_iodevice_reason()

  @doc ~S"""
  Apply updates to the dir cache and rewrite the index tree accordingly.

  ## Parameters

  `add`: a list of `Xgit.Core.DirCache.Entry` structs to add to the dir cache.
  In the event of collisions with existing entries, the existing entries will
  be replaced with the corresponding new entries.

  `remove`: a list of `{path, stage}` tuples to remove from the dir cache.
  `stage` must be `0..3` to remove a specific stage entry or `:all` to match
  any entry for the `path`.

  ## Return Values

  `{:ok, dir_cache}` where `dir_cache` is the original `dir_cache` with the new
  entries added (and properly sorted) and targeted entries removed.

  `{:error, reason}` if unable. The relevant reason codes may come from:

  * `Xgit.Core.DirCache.add_entries/2`
  * `Xgit.Core.DirCache.remove_entries/2`
  * `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1`
  * `Xgit.Repository.WorkingTree.WriteIndexFile.to_iodevice/2`.

  ## TO DO

  Find index file in appropriate location (i.e. as potentially modified
  by `.git/config` file). [Issue #86](https://github.com/elixir-git/xgit/issues/86)

  Cache state of index file so we don't have to parse it for every
  call. [Issue #87](https://github.com/elixir-git/xgit/issues/87)
  """
  @spec update_dir_cache(
          working_tree :: t,
          add :: [DirCacheEntry.t()],
          remove :: [{path :: FilePath.t(), stage :: DirCacheEntry.stage_match()}]
        ) ::
          {:ok, DirCache.t()} | {:error, update_dir_cache_reason}
  def update_dir_cache(working_tree, add, remove)
      when is_pid(working_tree) and is_list(add) and is_list(remove),
      do: GenServer.call(working_tree, {:update_dir_cache, add, remove})

  defp handle_update_dir_cache(add, remove, %{index_path: index_path} = state) do
    with {:ok, dir_cache} <- parse_index_file_if_exists(index_path),
         {:ok, dir_cache} <- DirCache.add_entries(dir_cache, add),
         {:ok, dir_cache} <- DirCache.remove_entries(dir_cache, remove),
         :ok <- write_index_file(dir_cache, index_path) do
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @typedoc ~S"""
  Reason codes that can be returned by `read_tree/2`.
  """
  @type read_tree_reason ::
          :objects_missing
  # | DirCache.to_tree_objects_reason()
  # | ParseIndexFile.from_iodevice_reason()
  # | Repository.put_loose_object_reason()

  @doc ~S"""
  Read a `tree` object and any trees it may refer to and populate the dir cache accordingly.

  Does not update files in the working tree itself.

  Analogous to [`git read-tree`](https://git-scm.com/docs/git-read-tree).

  ## Parameters

  `object_id` is the object ID of the root working tree.

  ## Options

  `:missing_ok?`: `true` to ignore any objects that are referenced by the tree
  structures that are not present in the object database. Normally this would be an error.

  ## Return Value

  `:ok` if successful.

  `{:error, :tree_not_found}` if `object_id` or any of the tree object it references
  are not present in the object store.

  `{:error, :prefix_not_found}` if `prefix` was specified, but that prefix is not referenced
  in the tree structure.

  `{:error, :objects_missing}` if any of the objects referenced by the index
  are not present in the object store. (Exception: If `missing_ok?` is `true`,
  then this condition will be ignored.)

  Reason codes may also come from the following functions:

  (NEED TO REVISIT THIS LIST)

  * `Xgit.Core.Tree.from_object/1`
  * `Xgit.Repository.get_object/2`
  * `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1`

  ## TO DO

  Implement `--prefix` option. https://github.com/elixir-git/xgit/issues/175
  """
  @spec read_tree(working_tree :: t, object_id :: ObjectId.t(), missing_ok?: boolean) ::
          :ok | {:error, reason :: read_tree_reason}
  def read_tree(working_tree, object_id, opts \\ [])
      when is_pid(working_tree) and is_binary(object_id) and is_list(opts) do
    missing_ok? = validate_read_tree_options(opts)
    GenServer.call(working_tree, {:read_tree, object_id, missing_ok?})
  end

  defp validate_read_tree_options(opts) do
    missing_ok? = Keyword.get(opts, :missing_ok?, false)

    unless is_boolean(missing_ok?) do
      raise ArgumentError,
            "Xgit.Repository.WorkingTree.read_tree/3: missing_ok? #{inspect(missing_ok?)} is invalid"
    end

    missing_ok?
  end

  defp handle_read_tree(
         object_id,
         missing_ok?,
         %{repository: repository, index_path: index_path} = state
       ) do
    with {:ok, %DirCache{entries: entries} = dir_cache} <-
           tree_to_dir_cache(repository, object_id),
         {:has_all_objects?, true} <-
           {:has_all_objects?, has_all_objects?(repository, entries, missing_ok?)},
         :ok <- write_index_file(dir_cache, index_path) do
      cover {:reply, :ok, state}
    else
      {:error, reason} -> cover {:reply, {:error, reason}, state}
      {:has_all_objects?, false} -> cover {:reply, {:error, :objects_missing}, state}
    end
  end

  defp tree_to_dir_cache(repository, object_id) do
    case tree_to_dir_cache_entries(repository, object_id, '', []) do
      {:ok, reversed_entries} ->
        {:ok,
         %DirCache{
           version: 2,
           entry_count: Enum.count(reversed_entries),
           entries: Enum.reverse(reversed_entries)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp tree_to_dir_cache_entries(repository, object_id, prefix, acc) do
    with {:ok, object} <- Repository.get_object(repository, object_id),
         {:ok, %Tree{entries: tree_entries} = _tree} <- Tree.from_object(object) do
      tree_entries_to_dir_cache_entries(repository, tree_entries, prefix, acc)
      # TO DO: A malformed tree could cause an infinite loop here.
      # https://github.com/elixir-git/xgit/issues/178
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp tree_entries_to_dir_cache_entries(repository, tree_entries, prefix, acc)

  defp tree_entries_to_dir_cache_entries(_repository, [], _prefix, acc), do: {:ok, acc}

  defp tree_entries_to_dir_cache_entries(
         repository,
         [%{mode: 0o040000, object_id: object_id, name: name} = _tree_entry | tail],
         prefix,
         acc
       ) do
    case tree_to_dir_cache_entries(repository, object_id, append_to_prefix(prefix, name), acc) do
      {:ok, acc} ->
        tree_entries_to_dir_cache_entries(repository, tail, prefix, acc)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp tree_entries_to_dir_cache_entries(
         repository,
         [%{mode: mode, object_id: object_id, name: name} = _tree_entry | tail],
         prefix,
         acc
       ) do
    dir_cache_entry = %DirCacheEntry{
      name: append_to_prefix(prefix, name),
      stage: 0,
      object_id: object_id,
      mode: mode,
      size: 0,
      ctime: 0,
      mtime: 0
    }

    tree_entries_to_dir_cache_entries(repository, tail, prefix, [dir_cache_entry | acc])
  end

  defp append_to_prefix('', name), do: name
  defp append_to_prefix(prefix, name), do: '#{prefix}/#{name}'

  @typedoc ~S"""
  Reason codes that can be returned by `write_tree/2`.
  """
  @type write_tree_reason ::
          :incomplete_merge
          | :objects_missing
          | :prefix_not_found
          | DirCache.to_tree_objects_reason()
          | ParseIndexFile.from_iodevice_reason()
          | Repository.put_loose_object_reason()

  @doc ~S"""
  Translates the current dir cache, as reflected in its index file, to one or more
  tree objects.

  The working tree must be in a fully-merged state.

  ## Options

  `:missing_ok?`: `true` to ignore any objects that are referenced by the index
  file that are not present in the object database. Normally this would be an error.

  `:prefix`: (`Xgit.Core.FilePath`) if present, returns the `object_id` for the tree at
  the given subdirectory. If not present, writes a tree corresponding to the root.
  (The entire tree is written in either case.)

  ## Return Value

  `{:ok, object_id}` with the object ID for the tree that was generated. (If the exact tree
  specified by the index already existed, it will return that existing tree's ID.)

  `{:error, :incomplete_merge}` if any entry in the index file is not fully merged.

  `{:error, :objects_missing}` if any of the objects referenced by the index
  are not present in the object store. (Exception: If `missing_ok?` is `true`,
  then this condition will be ignored.)

  `{:error, :prefix_not_found}` if `prefix` was specified, but that prefix is not referenced
  in the index file.

  Reason codes may also come from the following functions:

  * `Xgit.Core.DirCache.to_tree_objects/2`
  * `Xgit.Repository.put_loose_object/2`
  * `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1`
  """
  @spec write_tree(working_tree :: t, missing_ok?: boolean, prefix: FilePath.t()) ::
          {:ok, object_id :: ObjectId.t()} | {:error, reason :: write_tree_reason}
  def write_tree(working_tree, opts \\ []) when is_pid(working_tree) do
    {missing_ok?, prefix} = validate_write_tree_options(opts)
    GenServer.call(working_tree, {:write_tree, missing_ok?, prefix})
  end

  defp validate_write_tree_options(opts) do
    missing_ok? = Keyword.get(opts, :missing_ok?, false)

    unless is_boolean(missing_ok?) do
      raise ArgumentError,
            "Xgit.Repository.WorkingTree.write_tree/2: missing_ok? #{inspect(missing_ok?)} is invalid"
    end

    prefix = Keyword.get(opts, :prefix, [])

    unless prefix == [] or FilePath.valid?(prefix) do
      raise ArgumentError,
            "Xgit.Repository.WorkingTree.write_tree/2: prefix #{inspect(prefix)} is invalid (should be a charlist, not a String)"
    end

    {missing_ok?, prefix}
  end

  defp handle_write_tree(
         missing_ok?,
         prefix,
         %{repository: repository, index_path: index_path} = state
       ) do
    with {:ok, %DirCache{entries: entries} = dir_cache} <- parse_index_file_if_exists(index_path),
         {:merged?, true} <- {:merged?, DirCache.fully_merged?(dir_cache)},
         {:has_all_objects?, true} <-
           {:has_all_objects?, has_all_objects?(repository, entries, missing_ok?)},
         {:ok, objects, %Object{id: object_id}} <- DirCache.to_tree_objects(dir_cache, prefix),
         :ok <- write_all_objects(repository, objects) do
      cover {:reply, {:ok, object_id}, state}
    else
      {:error, reason} -> cover {:reply, {:error, reason}, state}
      {:merged?, false} -> cover {:reply, {:error, :incomplete_merge}, state}
      {:has_all_objects?, false} -> cover {:reply, {:error, :objects_missing}, state}
    end
  end

  defp has_all_objects?(repository, entries, missing_ok?)

  defp has_all_objects?(_repository, _entries, true), do: cover(true)

  defp has_all_objects?(repository, entries, false) do
    entries
    |> Enum.chunk_every(100)
    |> Enum.all?(fn entries_chunk ->
      Repository.has_all_object_ids?(
        repository,
        Enum.map(entries_chunk, fn %{object_id: id} -> id end)
      )
    end)
  end

  defp write_all_objects(repository, objects)

  defp write_all_objects(_repository, []), do: cover(:ok)

  defp write_all_objects(repository, [object | tail]) do
    case Repository.put_loose_object(repository, object) do
      :ok -> write_all_objects(repository, tail)
      {:error, :object_exists} -> write_all_objects(repository, tail)
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp parse_index_file_if_exists(index_path) do
    with true <- File.exists?(index_path),
         {:ok, iodevice} when is_pid(iodevice) <- TrailingHashDevice.open_file(index_path) do
      res = ParseIndexFile.from_iodevice(iodevice)
      :ok = File.close(iodevice)

      res
    else
      false -> cover {:ok, DirCache.empty()}
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp write_index_file(dir_cache, index_path) do
    with {:ok, iodevice}
         when is_pid(iodevice) <- TrailingHashDevice.open_file_for_write(index_path),
         :ok <- WriteIndexFile.to_iodevice(dir_cache, iodevice),
         :ok <- File.close(iodevice) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_call(:valid_working_tree?, _from, state), do: {:reply, :valid_working_tree, state}

  def handle_call(:dir_cache, _from, state), do: handle_dir_cache(state)

  def handle_call(:reset_dir_cache, _from, state), do: handle_reset_dir_cache(state)

  def handle_call({:update_dir_cache, add, remove}, _from, state),
    do: handle_update_dir_cache(add, remove, state)

  def handle_call({:read_tree, object_id, missing_ok?}, _from, state),
    do: handle_read_tree(object_id, missing_ok?, state)

  def handle_call({:write_tree, missing_ok?, prefix}, _from, state),
    do: handle_write_tree(missing_ok?, prefix, state)

  def handle_call(message, _from, state) do
    Logger.warn("WorkingTree received unrecognized call #{inspect(message)}")
    {:reply, {:error, :unknown_message}, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _object, reason}, state), do: {:stop, reason, state}
end
