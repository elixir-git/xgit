defmodule Xgit.Plumbing.UpdateIndex.CacheInfo do
  @moduledoc ~S"""
  Update the index file to reflect new contents.

  Analogous to the `--cacheinfo` form of
  [`git update-index`](https://git-scm.com/docs/git-update-index#Documentation/git-update-index.txt---cacheinfoltmodegtltobjectgtltpathgt).
  """
  use Xgit.Core.FileMode

  alias Xgit.Core.DirCache.Entry, as: DirCacheEntry
  alias Xgit.Core.FilePath
  alias Xgit.Core.ObjectId
  alias Xgit.Repository
  alias Xgit.Repository.WorkingTree

  @typedoc ~S"""
  Cache info tuple `{mode, object_id, path}` to add to the index file.
  """
  @type add_entry :: {mode :: FileMode.t(), object_id :: ObjectId.t(), path :: FilePath.t()}

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason ::
          :invalid_repository
          | :invalid_entry
          | :bare
          | Xgit.Repository.WorkingTree.update_dir_cache_reason()

  @doc ~S"""
  Update the index file to reflect new contents.

  ## Parameters

  `repository` is the `Xgit.Repository` (PID) to which the new entries should be written.

  `add`: a list of tuples of `{mode, object_id, path}` entries to add to the dir cache.
  In the event of collisions with existing entries, the existing entries will
  be replaced with the corresponding new entries.

  `remove`: a list of paths to remove from the dir cache. All versions of the file,
  regardless of stage, will be removed.

  ## Return Value

  `:ok` if successful.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository` process.

  `{:error, :bare}` if `repository` doesn't have a working tree.

  `{:error, :invalid_entry}` if any tuple passed to `add` or `remove` was invalid.

  `{:error, :reason}` if unable. The relevant reason codes may come from
  `Xgit.Repository.WorkingTree.update_dir_cache/3`.
  """
  @spec run(repository :: Repository.t(), add :: [add_entry], remove :: [byte]) ::
          :ok | {:error, reason()}
  def run(repository, add, remove \\ [])
      when is_pid(repository) and is_list(add) and is_list(remove) do
    with {:repository_valid?, true} <- {:repository_valid?, Repository.valid?(repository)},
         {:items_to_add, add} when is_list(add) <- {:items_to_add, parse_add_entries(add)},
         {:items_to_remove, remove} when is_list(remove) <-
           {:items_to_remove, parse_remove_entries(remove)},
         {:working_tree, working_tree} when is_pid(working_tree) <-
           {:working_tree, Repository.default_working_tree(repository)} do
      WorkingTree.update_dir_cache(working_tree, add, remove)
    else
      {:repository_valid?, false} -> {:error, :invalid_repository}
      {:items_to_add, _} -> {:error, :invalid_entry}
      {:items_to_remove, _} -> {:error, :invalid_entry}
      {:working_tree, nil} -> {:error, :bare}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_add_entries(add) do
    if Enum.all?(add, &valid_add?/1),
      do: Enum.map(add, &map_add_entry/1),
      else: :invalid
  end

  defp valid_add?({mode, object_id, path})
       when is_file_mode(mode) and is_binary(object_id) and is_list(path) do
    ObjectId.valid?(object_id) and FilePath.check_path(path) == :ok
  end

  defp valid_add?(_), do: false

  defp map_add_entry({mode, object_id, path}) do
    %DirCacheEntry{
      name: path,
      stage: 0,
      object_id: object_id,
      mode: mode,
      size: 0,
      ctime: 0,
      ctime_ns: 0,
      mtime: 0,
      mtime_ns: 0,
      dev: 0,
      ino: 0,
      uid: 0,
      gid: 0,
      assume_valid?: false,
      extended?: false,
      skip_worktree?: false,
      intent_to_add?: false
    }
  end

  defp parse_remove_entries(remove) do
    if Enum.all?(remove, &valid_remove?/1),
      do: Enum.map(remove, &map_remove_entry/1),
      else: :invalid
  end

  defp valid_remove?(name) when is_list(name), do: true
  defp valid_remove?(_), do: false

  defp map_remove_entry(name), do: {name, :all}
end
