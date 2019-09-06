defmodule Xgit.Repository do
  @moduledoc ~S"""
  Represents an abstract git repository.

  ## Looking for Typical Git Commands?

  The operations to inspect or mutate a git repository are not located in this
  module. (See _Design Goals,_ below, and
  [the `README.md` file in the `lib/xgit` folder](https://github.com/elixir-git/xgit/tree/master/lib/xgit/)
  for an explanation.)

  You'll find these operations in the modules named `Xgit.Api.*` _(none yet as
  of this writing)_ and `Xgit.Plumbing.*`

  ## Design Goals

  Xgit intends to allow repositories to be stored in multiple different mechanisms.
  While it includes built-in support for local on-disk repositories
  (see `Xgit.Repository.OnDisk`), and in-lib repositories (see `Xgit.Repository.InMemory`),
  you could envision repositories stored entirely on a remote file system or database.

  ## Implementing a Storage Architecture

  To define a new mechanism for storing a git repo, start by creating a new module
  that `use`s this module and implements the required callbacks. Consider the
  information stored in a typical `.git` directory in a local repository. You will
  be building an alternative to that storage mechanism.
  """
  use GenServer

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Repository.WorkingTree

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
      {:ok, mod_state} -> cover {:ok, %{mod: mod, mod_state: mod_state, working_tree: nil}}
      {:stop, reason} -> cover {:stop, reason}
    end
  end

  @doc ~S"""
  Returns `true` if the argument is a PID representing a valid `Repository` process.
  """
  @spec valid?(repository :: term) :: boolean
  def valid?(repository) when is_pid(repository) do
    Process.alive?(repository) &&
      GenServer.call(repository, :valid_repository?) == :valid_repository
  end

  def valid?(_), do: cover(false)

  @doc ~S"""
  Get the default working tree if one has been attached.

  Other working trees may also be attached to this repository, but do not have
  special status with regard to the repository.
  """
  @spec default_working_tree(repository :: t) :: WorkingTree.t() | nil
  def default_working_tree(repository) when is_pid(repository),
    do: GenServer.call(repository, :default_working_tree)

  @doc ~S"""
  Attach a working tree to this repository as the default working tree.

  Future plumbing and API commands that target this repository will use this
  working tree unless otherwise dictated.

  ## Return Value

  `:ok` if the working tree was successfully attached.

  `:error` if a working tree was already attached or the proposed working tree
  was not valid.
  """
  @spec set_default_working_tree(repository :: t, working_tree :: WorkingTree.t()) :: :ok | :error
  def set_default_working_tree(repository, working_tree)
      when is_pid(repository) and is_pid(working_tree),
      do: GenServer.call(repository, {:set_default_working_tree, working_tree})

  @doc ~S"""
  Returns `true` if all objects in the list are present in the object dictionary.

  This limit is not enforced, but it's recommended to query for no more than ~100 object
  IDs at a time.
  """
  @spec has_all_object_ids?(repository :: t, object_ids :: [ObjectId.t()]) :: boolean
  def has_all_object_ids?(repository, object_ids) when is_pid(repository) and is_list(object_ids),
    do: GenServer.call(repository, {:has_all_object_ids?, object_ids})

  @doc ~S"""
  Checks for presence of multiple object Ids.

  Called when `has_all_object_ids?/2` is called.

  ## Return Value

  Should return `{:ok, has_all_object_ids?, state}` where `has_all_object_ids?` is `true`
  if all object IDs can be found in the object dictionary; `false` otherwise.
  """
  @callback handle_has_all_object_ids?(state :: any, object_ids :: [ObjectId.t()]) ::
              {:ok, has_all_object_ids? :: boolean, state :: any}

  @typedoc ~S"""
  Error codes that can be returned by `get_object/2`.
  """
  @type get_object_reason :: :not_found | :invalid_object

  @doc ~S"""
  Retrieves an object from the repository.

  ## Return Value

  `{:ok, object}` if the object exists in the database.

  `{:error, :not_found}` if the object does not exist in the database.

  `{:error, :invalid_object}` if object was found, but invalid.
  """
  @spec get_object(repository :: t, object_id :: ObjectId.t()) ::
          {:ok, object :: Object.t()} | {:error, reason :: get_object_reason}
  def get_object(repository, object_id) when is_pid(repository) and is_binary(object_id),
    do: GenServer.call(repository, {:get_object, object_id})

  @doc ~S"""
  Retrieves an object from the repository.

  Called when `get_object/2` is called.

  ## Return Value

  Should return `{:ok, object, state}` if read successfully.

  Should return `{:error, :not_found, state}` if unable to find the object.

  Should return `{:error, :invalid_object, state}` if object was found, but invalid.
  """
  @callback handle_get_object(state :: any, object_id :: ObjectId.t()) ::
              {:ok, object :: Object.t(), state :: any}
              | {:error, reason :: get_object_reason, state :: any}

  @typedoc ~S"""
  Error codes that can be returned by `put_loose_object/2`.
  """

  @type put_loose_object_reason :: :cant_create_file | :object_exists

  @doc ~S"""
  Writes a loose object to the repository.

  ## Return Value

  `:ok` if written successfully.

  `{:error, :cant_create_file}` if unable to create the storage for the loose object.

  `{:error, :object_exists}` if the object already exists in the database.
  """
  @spec put_loose_object(repository :: t, object :: Object.t()) ::
          :ok | {:error, reason :: put_loose_object_reason}
  def put_loose_object(repository, %Object{} = object) when is_pid(repository),
    do: GenServer.call(repository, {:put_loose_object, object})

  @doc ~S"""
  Writes a loose object to the repository.

  Called when `put_loose_object/2` is called.

  ## Return Value

  Should return `{:ok, state}` if written successfully.

  Should return `{:error, :cant_create_file}` if unable to create the storage for
  the loose object.

  Should return `{:error, :object_exists}` if the object already exists in the database.
  """
  @callback handle_put_loose_object(state :: any, object :: Object.t()) ::
              {:ok, state :: any} | {:error, reason :: put_loose_object_reason, state :: any}

  @impl true
  def handle_call(:valid_repository?, _from, state), do: {:reply, :valid_repository, state}

  def handle_call(:default_working_tree, _from, %{working_tree: working_tree} = state),
    do: {:reply, working_tree, state}

  def handle_call({:set_default_working_tree, working_tree}, _from, %{working_tree: nil} = state) do
    if WorkingTree.valid?(working_tree) do
      {:reply, :ok, %{state | working_tree: working_tree}}
    else
      {:reply, :error, state}
    end
  end

  def handle_call({:set_default_working_tree, _working_tree}, _from, state),
    do: {:reply, :error, state}

  def handle_call({:has_all_object_ids?, object_ids}, _from, state),
    do: delegate_boolean_call_to(state, :handle_has_all_object_ids?, [object_ids])

  def handle_call({:get_object, object_id}, _from, state),
    do: delegate_call_to(state, :handle_get_object, [object_id])

  def handle_call({:put_loose_object, %Object{} = object}, _from, state),
    do: delegate_call_to(state, :handle_put_loose_object, [object])

  def handle_call(message, _from, state) do
    Logger.warn("Repository received unrecognized call #{inspect(message)}")
    {:reply, {:error, :unknown_message}, state}
  end

  defp delegate_call_to(%{mod: mod, mod_state: mod_state} = state, function, args) do
    case apply(mod, function, [mod_state | args]) do
      {:ok, mod_state} -> {:reply, :ok, %{state | mod_state: mod_state}}
      {:ok, response, mod_state} -> {:reply, {:ok, response}, %{state | mod_state: mod_state}}
      {:error, reason, mod_state} -> {:reply, {:error, reason}, %{state | mod_state: mod_state}}
    end
  end

  defp delegate_boolean_call_to(state, function, args) do
    {:reply, {:ok, response}, state} = delegate_call_to(state, function, args)
    cover {:reply, response, state}
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer, opts
      alias Xgit.Repository
      @behaviour Repository
    end
  end
end
