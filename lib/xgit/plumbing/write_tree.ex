defmodule Xgit.Plumbing.WriteTree do
  @moduledoc ~S"""
  Write the index file as a `tree` object.

  Analogous to
  [`git write-tree`](https://git-scm.com/docs/git-write-tree).
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.DirCache
  alias Xgit.Core.FilePath
  alias Xgit.Core.ObjectId
  alias Xgit.Plumbing.Util.WorkingTreeOpt
  alias Xgit.Repository.Storage
  alias Xgit.Repository.WorkingTree
  alias Xgit.Repository.WorkingTree.ParseIndexFile

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason ::
          :invalid_repository
          | :bare
          | WorkingTree.write_tree_reason()
          | DirCache.to_tree_objects_reason()
          | ParseIndexFile.from_iodevice_reason()
          | Storage.put_loose_object_reason()

  @doc ~S"""
  Translates the current working tree, as reflected in its index file, to one or more
  tree objects.

  The working tree must be in a fully-merged state.

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  ## Options

  `:missing_ok?`: `true` to ignore any objects that are referenced by the index
  file that are not present in the object database. Normally this would be an error.

  `:prefix`: (`Xgit.Core.FilePath`) if present, returns the `object_id` for the tree at
  the given subdirectory. If not present, writes a tree corresponding to the root.
  (The entire tree is written in either case.)

  ## Return Value

  `{:ok, object_id}` with the object ID for the tree that was generated. (If the exact tree
  specified by the index already existed, it will return that existing tree's ID.)

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :bare}` if `repository` doesn't have a working tree.

  Reason codes may also come from the following functions:

  * `Xgit.Core.DirCache.to_tree_objects/2`
  * `Xgit.Repository.Storage.put_loose_object/2`
  * `Xgit.Repository.Storage.WorkingTree.write_tree/2`
  * `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1`
  """
  @spec run(repository :: Storage.t(), missing_ok?: boolean, prefix: FilePath.t()) ::
          {:ok, object_id :: ObjectId.t()}
          | {:error, reason :: reason}
  def run(repository, opts \\ []) when is_pid(repository) do
    with {:ok, working_tree} <- WorkingTreeOpt.get(repository),
         _ <- validate_options(opts) do
      cover WorkingTree.write_tree(working_tree, opts)
    else
      {:error, reason} -> cover {:error, reason}
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
end
