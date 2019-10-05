defmodule Xgit.Repository.OnDisk do
  @moduledoc ~S"""
  Implementation of `Xgit.Repository` that stores content on the local file system.

  _IMPORTANT NOTE:_ This is intended as a reference implementation largely
  for testing purposes and may not necessarily handle all of the edge cases that
  the traditional `git` command-line interface will handle.

  That said, it does intentionally use the same `.git` folder format as command-line
  `git` so that results may be compared for similar operations.
  """
  use Xgit.Repository

  import Xgit.Util.ForceCoverage

  alias Xgit.Repository.WorkingTree

  @doc ~S"""
  Start an on-disk git repository.

  Use the functions in `Xgit.Repository` to interact with this repository process.

  An `Xgit.Repository.WorkingTree` will be automatically created and attached
  to this repository.

  ## Options

  * `:work_dir` (required): Top-level working directory. A `.git` directory should
    exist at this path. Use `create/1` to create an empty on-disk repository if
    necessary.

  Any other options are passed through to `GenServer.start_link/3`.

  ## Return Value

  See `GenServer.start_link/3`.

  `{:error, :work_dir_invalid}` if `work_dir` is missing or not a String.
  """
  @spec start_link(work_dir: Path.t()) :: GenServer.on_start()
  def start_link(opts) do
    with {:ok, work_dir} <- get_work_dir_opt(opts),
         {:ok, repo} <- Repository.start_link(__MODULE__, work_dir, opts),
         {:ok, working_tree} <- WorkingTree.start_link(repo, work_dir),
         :ok <- Repository.set_default_working_tree(repo, working_tree) do
      cover {:ok, repo}
    else
      err -> err
    end
  end

  defp get_work_dir_opt(opts) do
    with {:has_opt?, true} <- {:has_opt?, Keyword.has_key?(opts, :work_dir)},
         work_dir <- Keyword.get(opts, :work_dir),
         true <- is_binary(work_dir) do
      {:ok, work_dir}
    else
      {:has_opt?, _} -> {:error, :missing_arguments}
      _ -> {:error, :work_dir_invalid}
    end
  end

  @impl true
  def init(work_dir) when is_binary(work_dir) do
    # TO DO: Be smarter about bare repos and non-standard git_dir locations.
    # https://github.com/elixir-git/xgit/issues/44

    with {:work_dir, true} <- {:work_dir, File.dir?(work_dir)},
         git_dir <- Path.join(work_dir, ".git"),
         {:git_dir, true} <- {:git_dir, File.dir?(git_dir)} do
      cover {:ok, %{work_dir: work_dir, git_dir: git_dir}}
    else
      {:work_dir, _} -> cover {:stop, :work_dir_doesnt_exist}
      {:git_dir, _} -> cover {:stop, :git_dir_doesnt_exist}
    end
  end

  @doc ~S"""
  Creates a new, empty git repository on the local file system.

  Analogous to [`git init`](https://git-scm.com/docs/git-init).

  _NOTE:_ We use the name `create` here so as to avoid a naming conflict with
  `c:GenServer.init/1`.

  ## Parameters

  `work_dir` (String) is the top-level working directory. A `.git` directory is
  created inside this directory.

  ## Return Value

  `:ok` if created successfully.

  `{:error, :work_dir_must_not_exist}` if `work_dir` already exists.
  """
  @spec create(work_dir :: Path.t()) :: :ok | {:error, :work_dir_must_not_exist}
  defdelegate create(work_dir), to: Xgit.Repository.OnDisk.Create

  @impl true
  defdelegate handle_has_all_object_ids?(state, object_ids),
    to: Xgit.Repository.OnDisk.HasAllObjectIds

  @impl true
  defdelegate handle_get_object(state, object_id),
    to: Xgit.Repository.OnDisk.GetObject

  @impl true
  defdelegate handle_put_loose_object(state, object),
    to: Xgit.Repository.OnDisk.PutLooseObject
end
