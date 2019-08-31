defmodule Xgit.Plumbing.Util.WorkingTreeOpt do
  @moduledoc false
  # For use by plumbing modules only.

  import Xgit.Util.ForceCoverage

  alias Xgit.Repository
  alias Xgit.Repository.WorkingTree

  # Parse working tree and repository from arguments and options.

  @spec get(repository :: Repository.t(), working_tree: WorkingTree.t()) ::
          {:ok, WorkingTree.t()} | {:error, :invalid_repository | :bare}
  def get(repository, opts \\ []) when is_pid(repository) and is_list(opts) do
    with {:repository_valid?, true} <- {:repository_valid?, Repository.valid?(repository)},
         {:working_tree, working_tree} when is_pid(working_tree) <-
           {:working_tree, working_tree_from_repo_or_opts(repository, opts)} do
      cover {:ok, working_tree}
    else
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
      {:working_tree, nil} -> cover {:error, :bare}
    end
  end

  defp working_tree_from_repo_or_opts(repository, _opts) do
    # TO DO: Allow working tree to be specified via options.
    # https://github.com/elixir-git/xgit/issues/133
    # (NOTE: Should follow through to ensure all relevant plumbing
    # modules have that option documented when implemented.)
    # For now, only recognize default working tree.

    Repository.default_working_tree(repository)
  end
end
