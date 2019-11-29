defmodule Xgit.Plumbing.UpdateRef do
  @moduledoc ~S"""
  Update the object name stored in a ref.

  Analogous to
  [`git update-ref`](https://git-scm.com/docs/git-update-ref).
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.ObjectId
  alias Xgit.Core.Ref
  alias Xgit.Repository

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason :: :invalid_repository | Repository.put_ref_reason()

  @doc ~S"""
  Translates the current working tree, as reflected in its index file, to one or more
  tree objects.

  The working tree must be in a fully-merged state.

  ## Parameters

  `repository` is the `Xgit.Repository` (PID) to search for the object.

  `name` is the name of the reference to update. (See `t/Xgit.Core.Ref.name`.)

  `new_value` is the object ID to be written at this reference. (Use `Xgit.Core.ObjectId.zero/0` to delete the reference.)

  ## Options

  `old_target`: If present, a ref with this name must already exist and the `target`
  value must match the object ID provided in this option. (There is a special value `:new`
  which instead requires that the named ref must **not** exist.)

  ## Return Value

  `:ok` if written successfully.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository` process.

  Reason codes may also come from the following functions:

  * `Xgit.Repository.put_ref/3`
  * `Xgit.Repository.delete_ref/3`
  """
  @spec run(repository :: Repository.t(), name :: Ref.name(), new_value :: ObjectId.t(),
          old_target: ObjectId.t()
        ) :: :ok | {:error, reason}
  def run(repository, name, new_value, opts \\ [])
      when is_pid(repository) and is_binary(name) and is_binary(new_value) and is_list(opts) do
    with {:repository_valid?, true} <- {:repository_valid?, Repository.valid?(repository)},
         repo_opts <- validate_opts(opts) do
      if new_value == ObjectId.zero() do
        Repository.delete_ref(repository, name, repo_opts)
      else
        Repository.put_ref(repository, %Ref{name: name, target: new_value}, repo_opts)
      end
    else
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
    end
  end

  defp validate_opts(opts) do
    case validate_old_target(Keyword.get(opts, :old_target, nil)) do
      nil -> cover []
      old_target -> cover [{:old_target, old_target}]
    end
  end

  defp validate_old_target(nil) do
    cover nil
  end

  defp validate_old_target(:new) do
    cover :new
  end

  defp validate_old_target(old_target) do
    if ObjectId.valid?(old_target) do
      cover old_target
    else
      raise ArgumentError,
            "Xgit.Plumbing.UpdateRef.run/4: old_target #{inspect(old_target)} is invalid"
    end
  end
end
