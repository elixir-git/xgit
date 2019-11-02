defmodule Xgit.Repository.InMemory do
  @moduledoc ~S"""
  Implementation of `Xgit.Repository` that stores content in memory.

  _WARNING:_ This is intended for testing purposes only. As the name implies,
  repository content is stored only in memory. When the process that implements
  this repository terminates, the content it stores is lost.
  """
  use Xgit.Repository

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.ContentSource
  alias Xgit.Core.Object

  @doc ~S"""
  Start an in-memory git repository.

  Use the functions in `Xgit.Repository` to interact with this repository process.

  Any options are passed through to `GenServer.start_link/3`.

  ## Return Value

  See `GenServer.start_link/3`.
  """
  @spec start_link(opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []), do: Repository.start_link(__MODULE__, opts, opts)

  @impl true
  def init(opts) when is_list(opts), do: cover({:ok, %{loose_objects: %{}}})

  @impl true
  def handle_has_all_object_ids?(%{loose_objects: objects} = state, object_ids) do
    has_all_objects? = Enum.all?(object_ids, fn object_id -> Map.has_key?(objects, object_id) end)
    cover {:ok, has_all_objects?, state}
  end

  @impl true
  def handle_get_object(%{loose_objects: objects} = state, object_id) do
    # Currently only checks for loose objects.
    # TO DO: Look for object in packs.
    # https://github.com/elixir-git/xgit/issues/52

    case Map.get(objects, object_id) do
      %Object{} = object -> {:ok, object, state}
      nil -> {:error, :not_found, state}
    end
  end

  @impl true
  def handle_put_loose_object(%{loose_objects: loose_objects} = state, %Object{id: id} = object) do
    if Map.has_key?(loose_objects, id) do
      {:error, :object_exists, state}
    else
      # Convert any pending content into a byte list.
      # We don't bother with zlib compression here.
      new_objects = Map.put(loose_objects, id, maybe_read_object_content(object))
      cover {:ok, %{state | loose_objects: new_objects}}
    end
  end

  defp maybe_read_object_content(%Object{content: content} = object) when is_list(content),
    do: object

  defp maybe_read_object_content(%Object{content: content} = object),
    do: %{object | content: content |> ContentSource.stream() |> Enum.concat()}

  @impl true
  def handle_list_refs(state) do
    cover {:error, :unimplemented, state}
  end

  @impl true
  def handle_put_ref(state, _ref, _opts) do
    cover {:error, :unimplemented, state}
  end

  @impl true
  def handle_get_ref(state, _name, _opts) do
    cover {:error, :unimplemented, state}
  end
end
