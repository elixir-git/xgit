defmodule Xgit.Repository do
  @moduledoc ~S"""
  Represents an abstract git repository.

  ## Design Goals

  Xgit intends to allow repositories to be stored in multiple different mechanisms.
  While it includes built-in support for local on-disk repositories
  (see `Xgit.Repository.OnDisk`), you could envision repositories stored entirely
  in memory, or on a remote file system or database.

  In Elixir/OTP terms, a repository is both a `GenServer` and a behaviour module.

  In git terms, a repository (and thus any module that implements the behaviours
  defined here) is primary a **plumbing** module.

  The git **porcelain** implementations are largely implemented in a way that is
  intended to be agnostic with regard to storage. They are largely implemented
  in separate "command" modules. (See `Xgit.Command.*`, though no such module
  exists as of yet.)

  ## Implementing a Storage Architecture

  To define a new mechanism for storing a git repo, start by creating a new module
  that `use`s this module and implements the required callbacks. Consider the
  information stored in a typical `.git` directory in a local repository. You will
  be building an alternative to that storage mechanism.
  """

  use GenServer

  require Logger

  @typedoc ~S"""
  The process ID for a `Repository` process.
  """
  @type t :: pid

  @doc """
  Starts a `Repository` process linked to the current process.

  _IMPORTANT:_ You should not invoke this function directly unless you are
  implementing a new storage implementation module that implements this behaviour.

  ## Parameters

  `module` is the name of a module that implements the callbacks defined in this module.

  `init_arg` is passed to the `init/1` function of `module`.

  `options` are passed to `GenServer.start_link/3`.

  ## Return Value

  See `GenServer.start_link/3`.
  """
  @spec start_link(module :: module, init_arg :: term, GenServer.options()) ::
          GenServer.on_start()
  def start_link(module, init_arg, options) when is_atom(module) and is_list(options),
    do: GenServer.start_link(__MODULE__, {module, init_arg}, options)

  @impl true
  def init({mod, mod_init_arg}) do
    case mod.init(mod_init_arg) do
      {:ok, state} -> {:ok, {mod, state}}
      {:stop, reason} -> {:stop, reason}
    end
  end

  @doc ~S"""
  Returns `true` if the argument is a PID representing a valid `Repository` process.
  """
  @spec valid?(repository :: term) :: boolean
  def valid?(repository) when is_pid(repository),
    do:
      Process.alive?(repository) &&
        GenServer.call(repository, :valid_repository?) == :valid_repository

  def valid?(_), do: false

  @impl true
  def handle_call(:valid_repository?, _from, state), do: {:reply, :valid_repository, state}

  def handle_call(message, _from, state) do
    Logger.warn("Repository received unrecognized call #{inspect(message)}")
    {:reply, {:error, :unknown_message}, state}
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer, opts

      alias Xgit.Repository

      # @behaviour Repository (not yet, but it will be)
    end
  end
end
