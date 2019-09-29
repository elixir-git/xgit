defmodule Xgit.Plumbing.ReadTree do
  @moduledoc ~S"""
  Read a `tree` object (and its descendants) and populate the index accordingly.

  Analogous to
  [`git read-tree`](https://git-scm.com/docs/git-read-tree).
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.ObjectId
  alias Xgit.Plumbing.Util.WorkingTreeOpt
  alias Xgit.Repository
  alias Xgit.Repository.WorkingTree

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason ::
          :invalid_repository
          | :bare
          | WorkingTree.read_tree_reason()

  @doc ~S"""
  Read a `tree` object (and its descendants) and populate the index accordingly.

  Does not update files in the working tree itself.

  Analogous to [`git read-tree`](https://git-scm.com/docs/git-read-tree).

  ## Parameters

  `repository` is the `Xgit.Repository` (PID) to search for the object.

  `object_id` is the object ID of the root working tree. The special name `:empty`
  may be used to empty the index.

  ## Options

  `:missing_ok?`: `true` to ignore any objects that are referenced by the tree
  structures that are not present in the object database. Normally this would be an error.

  ## Return Value

  `:ok` if successful.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository` process.

  `{:error, :bare}` if `repository` doesn't have a working tree.

  Reason codes may also come from the following functions:

  * `Xgit.Core.Tree.from_object/1`
  * `Xgit.Repository.get_object/2`
  * `Xgit.Repository.WorkingTree.read_tree/3`
  * `Xgit.Repository.WorkingTree.WriteIndexFile.to_iodevice/2`

  ## TO DO

  Implement `--prefix` option. https://github.com/elixir-git/xgit/issues/175
  """
  @spec run(repository :: Repository.t(), object_id :: ObjectId.t(), missing_ok?: boolean) ::
          :ok | {:error, reason :: reason}
  def run(repository, object_id, opts \\ [])
      when is_pid(repository) and (is_binary(object_id) or object_id == :empty) and is_list(opts) do
    with {:ok, working_tree} <- WorkingTreeOpt.get(repository),
         _missing_ok? <- validate_options(opts) do
      if object_id == :empty do
        WorkingTree.reset_dir_cache(working_tree)
      else
        WorkingTree.read_tree(working_tree, object_id, opts)
      end
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp validate_options(opts) do
    missing_ok? = Keyword.get(opts, :missing_ok?, false)

    unless is_boolean(missing_ok?) do
      raise ArgumentError,
            "Xgit.Plumbing.ReadTree.run/3: missing_ok? #{inspect(missing_ok?)} is invalid"
    end

    missing_ok?
  end
end
