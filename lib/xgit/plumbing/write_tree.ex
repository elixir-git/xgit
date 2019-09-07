defmodule Xgit.Plumbing.WriteTree do
  @moduledoc ~S"""
  Write the index file as a `tree` object.

  Analogous to
  [`git write-tree`](https://git-scm.com/docs/git-write-tree).
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.DirCache
  alias Xgit.Core.FilePath
  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Plumbing.Util.WorkingTreeOpt
  alias Xgit.Repository
  alias Xgit.Repository.WorkingTree
  alias Xgit.Repository.WorkingTree.ParseIndexFile

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason ::
          :invalid_repository
          | :bare
          | :incomplete_merge
          | :objects_missing
          | DirCache.to_tree_objects_reason()
          | ParseIndexFile.from_iodevice_reason()
          | Repository.put_loose_object_reason()

  @doc ~S"""
  Retrieves information about files in the working tree as described by the index file.

  The working tree must be in a fully-merged state.

  ## Parameters

  `repository` is the `Xgit.Repository` (PID) to search for the object.

  ## Options

  `:missing_ok?`: `true` to ignore any objects that are referenced by the index
  file that are not present in the object database. Normally this would be an error.

  `:prefix`: (`Xgit.Core.FilePath`) if present, returns the `object_id` for the tree at
  the given subdirectory.  If not present, writes a tree corresponding to the root.
  (The entire tree is written in either case.)

  ## Return Value

  `{:ok, object_id}` with the object ID for the tree that was generated. (If the exact tree
  specified by the index already existed, it will return that existing tree's ID.)

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository` process.

  `{:error, :bare}` if `repository` doesn't have a working tree.

  `{:error, :incomplete_merge}` if any entry in the index file is not fully merged.

  `{:error, :objects_missing}` if any of the objects referenced by the index
  are not present in the object store. (Exception: If `missing_ok?` is `true`,
  then this condition will be ignored.)

  Reason codes may also come from the following functions:

  * `Xgit.Core.DirCache.to_tree_objects/2`
  * `Xgit.Repository.put_loose_object/2`
  * `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1`
  """
  @spec run(repository :: Repository.t(), missing_ok?: boolean, prefix: FilePath.t()) ::
          {:ok, object_id :: ObjectId.t()}
          | {:error, reason :: reason}
  def run(repository, opts \\ []) when is_pid(repository) do
    with {:ok, working_tree} <- WorkingTreeOpt.get(repository),
         {missing_ok?, prefix} <- validate_options(opts),
         {:ok, %DirCache{entries: entries} = dir_cache} <- WorkingTree.dir_cache(working_tree),
         {:merged?, true} <- {:merged?, DirCache.fully_merged?(dir_cache)},
         {:has_all_objects?, true} <-
           {:has_all_objects?, has_all_objects?(repository, entries, missing_ok?)},
         {:ok, objects, %Object{id: object_id}} <- DirCache.to_tree_objects(dir_cache, prefix),
         :ok <- write_all_objects(repository, objects) do
      cover {:ok, object_id}
    else
      {:error, reason} -> cover {:error, reason}
      {:merged?, false} -> cover {:error, :incomplete_merge}
      {:has_all_objects?, false} -> cover {:error, :objects_missing}
    end
  end

  defp validate_options(opts) do
    missing_ok? = Keyword.get(opts, :missing_ok?, false)

    unless is_boolean(missing_ok?) do
      raise ArgumentError,
            "Xgit.Plumbing.WriteTree.run/2: missing_ok? #{inspect(missing_ok?)} is invalid"
    end

    prefix = Keyword.get(opts, :prefix, [])

    unless prefix == [] or FilePath.valid?(prefix) do
      raise ArgumentError,
            "Xgit.Plumbing.WriteTree.run/2: prefix #{inspect(prefix)} is invalid (should be a charlist, not a String)"
    end

    {missing_ok?, prefix}
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

  defp write_all_objects(_repository, []), do: :ok

  defp write_all_objects(repository, [object | tail]) do
    case Repository.put_loose_object(repository, object) do
      :ok -> write_all_objects(repository, tail)
      {:error, :object_exists} -> write_all_objects(repository, tail)
      {:error, reason} -> {:error, reason}
    end
  end
end
