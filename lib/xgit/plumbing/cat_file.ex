defmodule Xgit.Plumbing.CatFile do
  @moduledoc ~S"""
  Retrieves the content, type, and size information for a single object in a
  repository's object store.

  Analogous to the first form of [`git cat-file`](https://git-scm.com/docs/git-cat-file).
  """

  alias Xgit.Core.ContentSource
  alias Xgit.Core.ObjectId
  alias Xgit.Core.ObjectType
  alias Xgit.Repository

  @doc ~S"""
  Retrieves the content, type, and size information for a single object in a
  repository's object store.

  ## Parameters

  `repository` is the `Xgit.Repository` (PID) to search for the object.

  `object_id` is a string identifying the object.

  ## Return Value

  `{:ok, object}` if the object could be found. `object` is an instance of
  `Xgit.Core.Object` and can be used to retrieve content and other information
  about the underlying git object.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository` process.

  `{:error, :invalid_object_id}` if `object_id` can't be parsed as a valid git object ID.

  `{:error, :not_found}` if the object does not exist in the database.

  `{:error, :invalid_object}` if object was found, but invalid.
  """
  @spec run(content :: ContentSource.t(), type: ObjectType.t() | nil) ::
          {:ok, ObjectID.t()} | {:error, reason :: atom}
  def run(repository, object_id) when is_pid(repository) and is_binary(object_id) do
    with {:repository_valid?, true} <- {:repository_valid?, Repository.valid?(repository)},
         {:object_id_valid?, true} <- {:object_id_valid?, ObjectId.valid?(object_id)} do
      Repository.get_object(repository, object_id)
    else
      {:repository_valid?, false} -> {:error, :invalid_repository}
      {:object_id_valid?, false} -> {:error, :invalid_object_id}
    end
  end
end
