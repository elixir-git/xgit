defmodule Xgit.Plumbing.CatFile.Tree do
  @moduledoc ~S"""
  Retrieves a `tree` object from a repository's object store.

  Analogous to [`git cat-file -p`](https://git-scm.com/docs/git-cat-file#Documentation/git-cat-file.txt--p)
  when the target object is a `tree` object.
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.ObjectId
  alias Xgit.Core.Tree
  alias Xgit.Repository

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason ::
          :invalid_repository
          | :invalid_object_id
          | Repository.get_object_reason()
          | Tree.from_object_reason()

  @doc ~S"""
  Retrieves a `tree` object from a repository's object store and renders
  it as an `Xgit.Core.Tree` struct.

  ## Parameters

  `repository` is the `Xgit.Repository` (PID) to search for the object.

  `object_id` is a string identifying the object.

  ## Return Value

  `{:ok, tree}` if the object could be found and understood as a tree.
  `tree` is an instance of `Xgit.Core.Tree` and can be used to retrieve
  references to the members of that tree.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository` process.

  `{:error, :invalid_object_id}` if `object_id` can't be parsed as a valid git object ID.

  `{:error, reason}` if otherwise unable. The relevant reason codes may come from:

  * `Xgit.Core.Tree.from_object/1`.
  * `Xgit.Repository.get_object/2`
  """
  @spec run(repository :: Repository.t(), object_id :: ObjectId.t()) ::
          {:ok, tree :: Tree.t()} | {:error, reason :: reason}
  def run(repository, object_id) when is_pid(repository) and is_binary(object_id) do
    with {:repository_valid?, true} <- {:repository_valid?, Repository.valid?(repository)},
         {:object_id_valid?, true} <- {:object_id_valid?, ObjectId.valid?(object_id)},
         {:ok, object} <- Repository.get_object(repository, object_id) do
      Tree.from_object(object)
    else
      {:error, reason} -> cover {:error, reason}
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
      {:object_id_valid?, false} -> cover {:error, :invalid_object_id}
    end
  end
end
