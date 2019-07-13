defmodule Xgit.Repository.OnDisk do
  @moduledoc ~S"""
  Implementation of `Xgit.Repository` that stores content on the local file system.

  **IMPORTANT NOTE:** This is intended as a reference implementation largely
  for testing purposes and may not necessarily handle all of the edge cases that
  the traditional `git` command-line interface will handle.

  That said, it does intentionally use the same `.git` folder format as command-line
  git so that results may be compared for similar operations.
  """

  use Xgit.Repository

  @doc ~S"""
  Start an on-disk git repository.

  ## Options

  * **TBD**

  Any other options are passed through to `GenServer.start_link/3`.

  ## Return Value

  See `GenServer.start_link/3`.

  Use the functions in `Xgit.Repository` to interact with this repository process.
  """
  @spec start_link(opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []), do: Repository.start_link(__MODULE__, opts, opts)

  @impl GenServer
  def init(opts) when is_list(opts) do
    work_dir = Keyword.get(opts, :work_dir)
    {:ok, %{work_dir: work_dir}}
  end

  @doc ~S"""
  Creates a new, empty git repository on the local file system.

  Analogous to [`git init`](https://git-scm.com/docs/git-init).

  **NOTE:** We use the name `create` here so as to avoid a naming conflict with
  the `GenServer` callback named `init/1`.

  ## Options

  * `:work_dir` (required): Top-level working directory. A `.git` directory is
    created inside this directory.

  ## Return Value

  `:ok`

  ## Errors

  Will raise `ArgumentError` if options are incomplete or incorrect.

  Will raise `File.Error` or similar if unable to create the directory.
  """
  @spec create(work_dir: String.t()) :: :ok
  defdelegate create(opts), to: Xgit.Repository.OnDisk.Create
end
