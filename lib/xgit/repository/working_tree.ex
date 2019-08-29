defmodule Xgit.Repository.WorkingTree do
  @moduledoc ~S"""
  A working tree is an on-disk manifestation of a commit or pending commit in
  a git repository.

  An `Xgit.Repository` may have a default working tree associated with it or
  it may not. (Such a repository is often referred to as a "bare" repository.)

  More than one working tree may be associated with a repository, though this
  is not (currently) well-tested in Xgit.

  A working tree is itself strictly tied to a file system, but it need not be
  tied to an on-disk repository instance.

  _IMPORTANT NOTE:_ This is intended as a reference implementation largely
  for testing purposes and may not necessarily handle all of the edge cases that
  the traditional `git` command-line interface will handle.
  """
  use GenServer

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry, as: DirCacheEntry
  alias Xgit.Repository
  alias Xgit.Repository.WorkingTree.ParseIndexFile
  alias Xgit.Repository.WorkingTree.WriteIndexFile
  alias Xgit.Util.TrailingHashDevice

  require Logger

  @typedoc ~S"""
  The process ID for a `WorkingTree` process.
  """
  @type t :: pid

  @doc """
  Starts a `WorkingTree` process linked to the current process.

  ## Parameters

  `repository` is the associated `Xgit.Repository` process.

  `work_dir` is the root path for the working tree.

  `options` are passed to `GenServer.start_link/3`.

  ## Return Value

  See `GenServer.start_link/3`.

  If the process is unable to create the working directory root, the response
  will be `{:error, {:mkdir, :eexist}}` (or perhaps a different posix error code).
  """
  @spec start_link(repository :: Repository.t(), work_dir :: Path.t(), GenServer.options()) ::
          GenServer.on_start()
  def start_link(repository, work_dir, options \\ [])
      when is_pid(repository) and is_binary(work_dir) and is_list(options) do
    if Repository.valid?(repository),
      do: GenServer.start_link(__MODULE__, {repository, work_dir}, options),
      else: {:error, :invalid_repository}
  end

  @impl true
  def init({repository, work_dir}) do
    case File.mkdir_p(work_dir) do
      :ok ->
        Process.monitor(repository)
        # Read index file here or maybe in a :continue handler?
        {:ok, %{repository: repository, work_dir: work_dir}}

      {:error, reason} ->
        {:stop, {:mkdir, reason}}
    end
  end

  @doc ~S"""
  Returns `true` if the argument is a PID representing a valid `WorkingTree` process.
  """
  @spec valid?(working_tree :: term) :: boolean
  def valid?(working_tree) when is_pid(working_tree) do
    Process.alive?(working_tree) &&
      GenServer.call(working_tree, :valid_working_tree?) == :valid_working_tree
  end

  def valid?(_), do: false

  @doc ~S"""
  Returns a current snapshot of the working tree state.

  ## Return Value

  `{:ok, dir_cache}` if an index file exists and could be parsed as a dir cache file.

  `{:ok, dir_cache}` if no index file exists. (`dir_cache` will have zero entries.)

  `{:error, reason}` if the file exists but could not be parsed.

  See `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1` for possible
  reason codes.

  ## TO DO

  Find index file in appropriate location (i.e. as potentially modified
  by `.git/config` file). [Issue #86](https://github.com/elixir-git/xgit/issues/86)

  Cache state of index file so we don't have to parse it for every
  call. [Issue #87](https://github.com/elixir-git/xgit/issues/87)

  Consider scalability of passing a potentially large `Xgit.Core.DirCache` structure
  across process boundaries. [Issue #88](https://github.com/elixir-git/xgit/issues/88)
  """
  @spec dir_cache(working_tree :: t) ::
          {:ok, DirCache.t()} | {:error, reason :: ParseIndexFile.from_iodevice_reason()}
  def dir_cache(working_tree) when is_pid(working_tree),
    do: GenServer.call(working_tree, :dir_cache)

  defp handle_dir_cache(%{work_dir: work_dir} = state) do
    case parse_dir_cache_if_exists(work_dir) do
      {:ok, dir_cache} -> {:reply, {:ok, dir_cache}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp parse_dir_cache_if_exists(work_dir) do
    index_path = Path.join([work_dir, ".git", "index"])

    with true <- File.exists?(index_path),
         {:ok, iodevice} when is_pid(iodevice) <- TrailingHashDevice.open_file(index_path) do
      res = ParseIndexFile.from_iodevice(iodevice)
      :ok = File.close(iodevice)

      res
    else
      false -> {:ok, DirCache.empty()}
      {:error, reason} -> {:error, reason}
    end
  end

  @typedoc ~S"""
  Error code reasons returned by `update_dir_cache/3`.
  """
  @type update_dir_cache_reason ::
          DirCache.add_entries_reason()
          | DirCache.remove_entries_reason()
          | ParseIndexFile.from_iodevice_reason()
          | WriteIndexFile.to_iodevice_reason()

  @doc ~S"""
  Apply updates to the dir cache and rewrite the index tree accordingly.

  ## Parameters

  `add`: a list of `Xgit.Core.DirCache.Entry` structs to add to the dir cache.
  In the event of collisions with existing entries, the existing entries will
  be replaced with the corresponding new entries.

  `remove`: a list of `{path, stage}` tuples to remove from the dir cache.
  `stage` must be `0..3` to remove a specific stage entry or `:all` to match
  any entry for the `path`.

  ## Return Values

  `{:ok, dir_cache}` where `dir_cache` is the original `dir_cache` with the new
  entries added (and properly sorted) and targeted entries removed.

  `{:error, :reason}` if unable. The relevant reason codes may come from:

  * `Xgit.Core.DirCache.add_entries/2`
  * `Xgit.Core.DirCache.remove_entries/2`
  * `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1`
  * `Xgit.Repository.WorkingTree.WriteIndexFile.to_iodevice/2`.

  ## TO DO

  Find index file in appropriate location (i.e. as potentially modified
  by `.git/config` file). [Issue #86](https://github.com/elixir-git/xgit/issues/86)

  Cache state of index file so we don't have to parse it for every
  call. [Issue #87](https://github.com/elixir-git/xgit/issues/87)
  """
  @spec update_dir_cache(
          working_tree :: t,
          add :: [DirCacheEntry.t()],
          remove :: [{[path :: [byte]], stage :: DirCacheEntry.stage_match()}]
        ) ::
          {:ok, DirCache.t()} | {:error, update_dir_cache_reason}
  def update_dir_cache(working_tree, add, remove)
      when is_pid(working_tree) and is_list(add) and is_list(remove),
      do: GenServer.call(working_tree, {:update_dir_cache, add, remove})

  defp handle_update_dir_cache(add, remove, %{work_dir: work_dir} = state) do
    index_path = Path.join([work_dir, ".git", "index"])

    with {:ok, dir_cache} <- parse_dir_cache_if_exists(work_dir),
         {:ok, dir_cache} <- DirCache.add_entries(dir_cache, add),
         {:ok, dir_cache} <- DirCache.remove_entries(dir_cache, remove),
         {:ok, iodevice}
         when is_pid(iodevice) <- TrailingHashDevice.open_file_for_write(index_path),
         :ok <- WriteIndexFile.to_iodevice(dir_cache, iodevice),
         :ok <- File.close(iodevice) do
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:valid_working_tree?, _from, state), do: {:reply, :valid_working_tree, state}

  def handle_call(:dir_cache, _from, state), do: handle_dir_cache(state)

  def handle_call({:update_dir_cache, add, remove}, _from, state),
    do: handle_update_dir_cache(add, remove, state)

  def handle_call(message, _from, state) do
    Logger.warn("WorkingTree received unrecognized call #{inspect(message)}")
    {:reply, {:error, :unknown_message}, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _object, reason}, state), do: {:stop, reason, state}
end
