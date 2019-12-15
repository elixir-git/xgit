defmodule Xgit.Repository.Storage do
  @moduledoc ~S"""
  Represents the persistent storage for a git repository.

  Unless you are implementing an alternative storage architecture or implementing
  plumbing-level commands, this module is probably not of interest to you.

  ## Design Goals

  Xgit intends to allow repositories to be stored in multiple different mechanisms.
  While it includes built-in support for local on-disk repositories
  (see `Xgit.Repository.OnDisk`), and in-member repositories (see `Xgit.Repository.InMemory`),
  you could envision repositories stored entirely on a remote file system or database.

  ## Implementing a Storage Architecture

  To define a new mechanism for storing a git repo, create a new module that `use`s
  this module and implements the required callbacks. Consider the information stored
  in a typical `.git` directory in a local repository. You will be building an
  alternative to that storage mechanism.
  """
  use GenServer

  import Xgit.Util.ForceCoverage

  alias Xgit.Object
  alias Xgit.ObjectId
  alias Xgit.Ref
  alias Xgit.Repository.WorkingTree

  require Logger

  @typedoc ~S"""
  The process ID for an `Xgit.Repository.Storage` process.
  """
  @type t :: pid

  @doc """
  Starts an `Xgit.Repository.Storage` process linked to the current process.

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
  Returns `true` if the argument is a PID representing a valid `Xgit.Repository.Storage` process.
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

  @typedoc ~S"""
  Error codes that can be returned by `list_refs/1`.
  """
  @type list_refs_reason :: File.posix()

  @doc ~S"""
  Lists all references in the repository.

  ## Return Value

  `{:ok, refs}` if successful. `refs` will be a list of `Xgit.Ref` structs.
  The sequence of the list is unspecified.

  `{:error, reason}` if unable. See `list_refs_reason`.
  """
  @spec list_refs(repository :: t) ::
          {:ok, refs :: [Ref.t()]} | {:error, reason :: list_refs_reason}
  def list_refs(repository) when is_pid(repository),
    do: GenServer.call(repository, :list_refs)

  @doc ~S"""
  Lists all references in the repository.

  Called when `list_refs/1` is called.

  ## Return Value

  Should return `{:ok, refs, state}` if read successfully. `refs` should be a list
  of `Xgit.Ref` structs.

  Should return `{:error, reason}` if unable. Currently only `File.posix` reasons
  are expected.
  """
  @callback handle_list_refs(state :: any) ::
              {:ok, refs :: [Ref], state :: any}
              | {:error, reason :: list_refs_reason, state :: any}

  @typedoc ~S"""
  Error codes that can be returned by `put_ref/3`.
  """
  @type put_ref_reason ::
          :invalid_ref
          | :cant_create_file
          | :target_not_found
          | :target_not_commit
          | :old_target_not_matched

  @doc ~S"""
  Writes or updates a reference in the repository.

  If any existing reference exists with this name, it will be replaced.

  ## Options

  `follow_link?`: (default: `true`) `true` to follow symbolic refs

  `old_target`: If present, a ref with this name must already exist and the `target`
  value must match the object ID provided in this option. (There is a special value `:new`
  which instead requires that the named ref must **not** exist.)

  ## TO DO

  Support for ref log. https://github.com/elixir-git/xgit/issues/224

  Support for `--no-deref` option. https://github.com/elixir-git/xgit/issues/226

  ## Return Value

  `:ok` if written successfully.

  `{:error, :invalid_ref}` if the `Xgit.Ref` structure is invalid.

  `{:error, :cant_create_file}` if unable to create the storage for the reference.

  `{:error, :target_not_found}` if the target object does not exist in the repository.

  `{:error, :target_not_commit}` if the target object is not of type `commit`.

  `{:error, :old_target_not_matched}` if `old_target` was specified and the target ref points
  to a different object ID.
  """
  @spec put_ref(repository :: t, ref :: Ref.t(), follow_link?: boolean, old_target: ObjectId.t()) ::
          :ok | {:error, reason :: put_ref_reason}
  def put_ref(repository, %Ref{} = ref, opts \\ []) when is_pid(repository) and is_list(opts) do
    if Ref.valid?(ref) do
      GenServer.call(repository, {:put_ref, ref, opts})
    else
      cover {:error, :invalid_ref}
    end
  end

  @doc ~S"""
  Writes or updates a reference in the repository.

  Called when `put_ref/3` is called.

  The implementation must validate that the referenced object exists and is of
  type `commit`. It does not need to validate that the reference is otherwise
  valid.

  ## Options

  `follow_link?`: (default: `true`) `true` to follow symbolic refs

  `old_target`: If present, a ref with this name must already exist and the `target`
  value must match the object ID provided in this option. (There is a special value `:new`
  which instead requires that the named ref must **not** exist.)

  ## Return Value

  Should return `{:ok, state}` if written successfully.

  Should return `{:error, :cant_create_file}` if unable to create the storage for
  the ref.

  Should return `{:error, :target_not_found}` if the target object does not
  exist in the repository.

  Should return `{:error, :target_not_commit}` if the target object is not
  of type `commit`.

  Should return `{:error, :old_target_not_matched}` if `old_target` was specified and the
  target ref points to a different object ID.
  """
  @callback handle_put_ref(state :: any, ref :: Ref.t(),
              follow_link?: boolean,
              old_target: ObjectId.t()
            ) ::
              {:ok, state :: any} | {:error, reason :: put_ref_reason, state :: any}

  @typedoc ~S"""
  Error codes that can be returned by `delete_ref/3`.
  """
  @type delete_ref_reason :: :invalid_ref | :cant_delete_file | :old_target_not_matched

  @doc ~S"""
  Deletes a reference from the repository.

  ## Options

  `old_target`: If present, a ref with this name must already exist and the `target`
  value must match the object ID provided in this option.

  ## TO DO

  `follow_link?` option. https://github.com/elixir-git/xgit/issues/249

  Support for ref log. https://github.com/elixir-git/xgit/issues/224

  Support for `--no-deref` option. https://github.com/elixir-git/xgit/issues/226

  ## Return Value

  `:ok` if deleted successfully or the reference did not exist.

  `{:error, :invalid_ref}` if `name` is not a valid ref name.

  `{:error, :cant_delete_file}` if unable to delete the storage for the reference.

  `{:error, :old_target_not_matched}` if `old_target` was specified and the target ref points
  to a different object ID or did not exist.
  """
  @spec delete_ref(repository :: t, name :: Ref.name(), old_target: ObjectId.t()) ::
          :ok | {:error, reason :: delete_ref_reason}
  def delete_ref(repository, name, opts \\ [])
      when is_pid(repository) and is_binary(name) and is_list(opts) do
    if Ref.valid_name?(name) do
      GenServer.call(repository, {:delete_ref, name, opts})
    else
      cover {:error, :invalid_ref}
    end
  end

  @doc ~S"""
  Deletes a reference in the repository.

  Called when `delete_ref/3` is called.

  ## Options

  `old_target`: If present, a ref with this name must already exist and the `target`
  value must match the object ID provided in this option.

  ## Return Value

  Should return `{:ok, state}` if deleted successfully or the ref did not exist.

  Should return `{:error, :cant_delete_file}` if unable to delete the storage for
  the ref.

  Should return `{:error, :old_target_not_matched}` if `old_target` was specified and the
  target ref points to a different object ID or the ref did not exist.
  """
  @callback handle_delete_ref(state :: any, name :: Ref.name(), old_target: ObjectId.t()) ::
              {:ok, state :: any} | {:error, reason :: delete_ref_reason, state :: any}

  @typedoc ~S"""
  Error codes that can be returned by `get_ref/2`.
  """
  @type get_ref_reason :: :invalid_name | :not_found

  @doc ~S"""
  Reads a reference from the repository.

  If any existing reference exists with this name, it will be returned.

  ## Parameters

  `name` is the name of the reference to be found. It must be a valid name
  as per `Xgit.Ref.valid_name?/1`.

  ## Options

  `follow_link?`: (default: `true`) `true` to follow symbolic refs

  ## TO DO

  Dereference tags? https://github.com/elixir-git/xgit/issues/228

  ## Return Value

  `{:ok, ref}` if the reference was found successfully. `ref` will be an
  `Xgit.Ref` struct.

  `{:error, :invalid_name}` if `name` is not a valid ref name.

  `{:error, :not_found}` if no such reference exists.
  """
  @spec get_ref(repository :: t, name :: String.t(), follow_link?: boolean) ::
          {:ok, ref :: Ref.t()} | {:error, reason :: get_ref_reason}
  def get_ref(repository, name, opts \\ [])
      when is_pid(repository) and is_binary(name) and is_list(opts) do
    if valid_ref_name?(name) do
      GenServer.call(repository, {:get_ref, name, opts})
    else
      cover {:error, :invalid_name}
    end
  end

  defp valid_ref_name?("HEAD"), do: cover(true)
  defp valid_ref_name?(name), do: Ref.valid_name?(name)

  @doc ~S"""
  Reads a reference from the repository.

  Called when `get_ref/3` is called.

  ## Options

  `follow_link?`: (default: `true`) `true` to follow symbolic refs

  ## Return Value

  Should return `{:ok, ref, state}` if the reference was found successfully.
  `ref` must be an `Xgit.Ref` struct.

  Should return `{:error, :not_found, state}` if no such reference exists.
  """
  @callback handle_get_ref(state :: any, name :: String.t(), follow_link?: boolean) ::
              {:ok, ref :: Xgit.Ref.t(), state :: any}
              | {:error, reason :: get_ref_reason, state :: any}

  # TO DO: Add a `pack_refs` function. https://github.com/elixir-git/xgit/issues/223

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

  def handle_call(:list_refs, _from, state),
    do: delegate_call_to(state, :handle_list_refs, [])

  def handle_call({:put_ref, %Ref{} = ref, opts}, _from, state),
    do: delegate_call_to(state, :handle_put_ref, [ref, opts])

  def handle_call({:delete_ref, name, opts}, _from, state),
    do: delegate_call_to(state, :handle_delete_ref, [name, opts])

  def handle_call({:get_ref, name, opts}, _from, state),
    do: delegate_call_to(state, :handle_get_ref, [name, opts])

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
      alias Xgit.Repository.Storage
      @behaviour Storage
    end
  end
end
