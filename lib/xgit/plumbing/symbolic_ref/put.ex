defmodule Xgit.Plumbing.SymbolicRef.Put do
  @moduledoc ~S"""
  Modify a symbolic ref in a repo.

  Analogous to the two-argument form of
  [`git symbolic-ref`](https://git-scm.com/docs/git-symbolic-ref).
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.Ref
  alias Xgit.Repository

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason :: :invalid_repository | Repository.put_ref_reason()

  @doc ~S"""
  Creates or updates a symbolic ref to point at a specific branch.

  ## Parameters

  `repository` is the `Xgit.Repository` (PID) in which to create the symbolic reference.

  `name` is the name of the symbolic reference to create or update. (See `t/Xgit.Core.Ref.name`.)

  `new_target` is the name of the reference that should be targeted by this symbolic reference.
  This reference need not exist.

  ## Options

  TO DO: Add option to specify ref log message.
  https://github.com/elixir-git/xgit/issues/251

  ## Return Value

  `:ok` if written successfully.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository` process.

  Reason codes may also come from the following functions:

  * `Xgit.Repository.put_ref/3`
  """
  @spec run(
          repository :: Repository.t(),
          name :: Ref.name(),
          new_target :: Ref.name(),
          opts :: Keyword.t()
        ) :: :ok | {:error, reason}
  def run(repository, name, new_target, opts \\ [])
      when is_pid(repository) and is_binary(name) and is_binary(new_target) and is_list(opts) do
    if Repository.valid?(repository) do
      Repository.put_ref(repository, %Ref{name: name, target: "ref: #{new_target}"},
        follow_link?: false
      )
    else
      cover {:error, :invalid_repository}
    end
  end
end
