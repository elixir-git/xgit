defmodule Xgit.Repository.InvalidRepositoryError do
  @moduledoc ~S"""
  Raised when a call is made to any `Xgit.Repository.*` API, but the
  process ID doesn't implement the `Xgit.Repository.Storage` API.
  """

  defexception message: "not a valid Xgit repository"
end
