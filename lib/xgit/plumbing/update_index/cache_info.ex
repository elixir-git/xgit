defmodule Xgit.Plumbing.UpdateIndex.CacheInfo do
  @moduledoc ~S"""
  Update the index file to reflect new contents.

  Analogous to the `--cacheinfo` form of
  [`git update-index`](https://git-scm.com/docs/git-update-index#Documentation/git-update-index.txt---cacheinfoltmodegtltobjectgtltpathgt).
  """
  use Xgit.Core.FileMode

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.DirCache.Entry, as: DirCacheEntry
  alias Xgit.Core.FilePath
  alias Xgit.Core.ObjectId
  alias Xgit.Plumbing.Util.WorkingTreeOpt
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
  @spec run(repository :: Repository.t(), add :: [add_entry], remove :: [FilePath.t()]) ::
          :ok | {:error, reason()}
  def run(repository, add, remove \\ [])
      when is_pid(repository) and is_list(add) and is_list(remove) do
    with {:ok, working_tree} <- WorkingTreeOpt.get(repository),
         {:items_to_add, add} when is_list(add) <- {:items_to_add, parse_add_entries(add)},
         {:items_to_remove, remove} when is_list(remove) <-
           {:items_to_remove, parse_remove_entries(remove)} do
      WorkingTree.update_dir_cache(working_tree, add, remove)
    else
      {:items_to_add, _} -> cover {:error, :invalid_entry}
      {:items_to_remove, _} -> cover {:error, :invalid_entry}
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp parse_add_entries(add) do
    if Enum.all?(add, &valid_add?/1) do
      Enum.map(add, &map_add_entry/1)
    else
      cover(:invalid)
    end
  end

  defp valid_add?({mode, object_id, path})
       when is_file_mode(mode) and is_binary(object_id) and is_list(path),
       do: ObjectId.valid?(object_id) and FilePath.valid?(path)

  defp valid_add?(_), do: cover(false)

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
    if Enum.all?(remove, &valid_remove?/1) do
      Enum.map(remove, &map_remove_entry/1)
    else
      cover(:invalid)
    end
  end

  defp valid_remove?(name) when is_list(name), do: cover(true)
  defp valid_remove?(_), do: cover(false)

  defp map_remove_entry(name), do: cover({name, :all})
end
