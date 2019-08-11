defmodule Xgit.Plumbing.LsFiles.Stage do
  @moduledoc ~S"""
  Show information about files in the index.

  Analogous to
  [`git ls-files --stage`](https://git-scm.com/docs/git-ls-files#Documentation/git-ls-files.txt---stage).
  """

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry, as: DirCacheEntry
  alias Xgit.Repository
  alias Xgit.Repository.WorkingTree
  alias Xgit.Repository.WorkingTree.ParseIndexFile

  @typedoc ~S"""
  Reason codes that can be returned by `run/1`.
  """
  @type reason :: :invalid_repository | ParseIndexFile.from_iodevice_reason()

  @doc ~S"""
  Retrieves information about files in the working tree as described by the index file.

  ## Parameters

  `repository` is the `Xgit.Repository` (PID) to search for the object.

  ## Return Value

  `{:ok, entries}`. `entries` will be a list of `Xgit.Core.DirCache.Entry` structs
  in sorted order.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository` process.

  `{:error, :bare}` if `repository` doesn't have a working tree.

  `{:error, reason}` if the index file for `repository` isn't valid. (See
  `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1` for possible
  reason codes.)
  """
  @spec run(repository :: Repository.t()) ::
          {:ok, entries :: [DirCacheEntry.t()]}
          | {:error, reason :: reason}
  def run(repository) when is_pid(repository) do
    with {:repository_valid?, true} <- {:repository_valid?, Repository.valid?(repository)},
         {:working_tree, working_tree} when is_pid(working_tree) <-
           {:working_tree, Repository.default_working_tree(repository)},
         {:dir_cache, {:ok, %DirCache{entries: entries} = _dir_cache}} <-
           {:dir_cache, WorkingTree.dir_cache(working_tree)} do
      {:ok, entries}
    else
      {:repository_valid?, false} -> {:error, :invalid_repository}
      {:working_tree, nil} -> {:error, :bare}
      {:dir_cache, {:error, reason}} -> {:error, reason}
    end
  end
end
