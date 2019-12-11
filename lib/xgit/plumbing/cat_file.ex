defmodule Xgit.Plumbing.CatFile do
  @moduledoc ~S"""
  Retrieves the content, type, and size information for a single object in a
  repository's object store.

  Analogous to the first form of [`git cat-file`](https://git-scm.com/docs/git-cat-file).
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Repository.Storage

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason :: :invalid_repository | :invalid_object_id

  @doc ~S"""
  Retrieves the content, type, and size information for a single object in a
  repository's object store.

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  `object_id` is a string identifying the object.

  ## Return Value

  `{:ok, object}` if the object could be found. `object` is an instance of
  `Xgit.Core.Object` and can be used to retrieve content and other information
  about the underlying git object.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :invalid_object_id}` if `object_id` can't be parsed as a valid git object ID.

  `{:error, :not_found}` if the object does not exist in the database.

  `{:error, :invalid_object}` if object was found, but invalid.
  """
  @spec run(repository :: Storage.t(), object_id :: ObjectId.t()) ::
          {:ok, Object}
          | {:error, reason :: reason}
          | {:error, reason :: Storage.get_object_reason()}
  def run(repository, object_id) when is_pid(repository) and is_binary(object_id) do
    with {:repository_valid?, true} <- {:repository_valid?, Storage.valid?(repository)},
         {:object_id_valid?, true} <- {:object_id_valid?, ObjectId.valid?(object_id)} do
      Storage.get_object(repository, object_id)
    else
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
      {:object_id_valid?, false} -> cover {:error, :invalid_object_id}
    end
  end
end
