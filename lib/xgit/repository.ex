defmodule Xgit.Repository do
  @moduledoc ~S"""
  Represents a git repository.

  Create a repository by calling the `start_link` function on one of the modules
  that implements `Xgit.Repository.Storage`. The resulting PID can be used when
  calling functions in this module and `Xgit.Repository.Plumbing`.

  The functions implemented in this module correspond to the "plumbing" commands
  implemented by command-line git.

  (As of this writing, no plumbing-level commands have been implemented yet.)
  """
  alias Xgit.Repository.Storage

  @typedoc ~S"""
  The process ID for an `Xgit.Repository` process.

  This is the same process ID returned from the `start_link` function of any
  module that implements `Xgit.Repository.Storage`.
  """
  @type t :: pid

  @doc ~S"""
  Returns `true` if the argument is a PID representing a valid `Xgit.Repository` process.
  """
  @spec valid?(repository :: term) :: boolean
  defdelegate valid?(repository), to: Storage
end
