defmodule Xgit.Plumbing.CatFile.Commit do
  @moduledoc ~S"""
  Retrieves a `commit` object from a repository's object store.

  Analogous to [`git cat-file -p`](https://git-scm.com/docs/git-cat-file#Documentation/git-cat-file.txt--p)
  when the target object is a `commit` object.
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.Commit
  alias Xgit.Core.ObjectId
  alias Xgit.Repository.Storage

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason ::
          :invalid_repository
          | :invalid_object_id
          | Commit.from_object_reason()
          | Storage.get_object_reason()

  @doc ~S"""
  Retrieves a `commit` object from a repository's object store and renders
  it as an `Xgit.Core.Commit` struct.

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  `object_id` is a string identifying the object.

  ## Return Value

  `{:ok, commit}` if the object could be found and understood as a commit.
  `commit` is an instance of `Xgit.Core.Commit` and can be used to retrieve
  references to the members of that commit.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :invalid_object_id}` if `object_id` can't be parsed as a valid git object ID.

  `{:error, reason}` if otherwise unable. The relevant reason codes may come from:

  * `Xgit.Core.Commit.from_object/1`.
  * `Xgit.Repository.Storage.get_object/2`
  """
  @spec run(repository :: Storage.t(), object_id :: ObjectId.t()) ::
          {:ok, commit :: Commit.t()} | {:error, reason :: reason}
  def run(repository, object_id) when is_pid(repository) and is_binary(object_id) do
    with {:repository_valid?, true} <- {:repository_valid?, Storage.valid?(repository)},
         {:object_id_valid?, true} <- {:object_id_valid?, ObjectId.valid?(object_id)},
         {:ok, object} <- Storage.get_object(repository, object_id) do
      Commit.from_object(object)
    else
      {:error, reason} -> cover {:error, reason}
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
      {:object_id_valid?, false} -> cover {:error, :invalid_object_id}
    end
  end
end
