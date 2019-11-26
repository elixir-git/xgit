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
  alias Xgit.Core.Ref

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
  def init(opts) when is_list(opts) do
    cover(
      {:ok,
       %{
         loose_objects: %{},
         refs: %{"HEAD" => %Ref{name: "HEAD", target: "ref: refs/heads/master"}}
       }}
    )
  end

  @impl true
  def handle_has_all_object_ids?(%{loose_objects: objects} = state, object_ids) do
    has_all_objects? = Enum.all?(object_ids, fn object_id -> Map.has_key?(objects, object_id) end)
    cover {:ok, has_all_objects?, state}
  end

  @impl true
  def handle_get_object(state, object_id) do
    case get_object_imp(state, object_id) do
      %Object{} = object -> cover {:ok, object, state}
      nil -> cover {:error, :not_found, state}
    end
  end

  defp get_object_imp(%{loose_objects: objects} = _state, object_id) do
    # Currently only checks for loose objects.
    # TO DO: Look for object in packs.
    # https://github.com/elixir-git/xgit/issues/52

    Map.get(objects, object_id)
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
  def handle_list_refs(%{refs: refs} = state) do
    cover {:ok, refs |> Map.values() |> Enum.filter(&heads_only/1) |> Enum.sort(), state}
  end

  defp heads_only(%Ref{name: "refs/heads/" <> _}), do: cover(true)
  defp heads_only(_), do: cover(false)

  @impl true
  def handle_put_ref(%{refs: refs} = state, %Ref{name: name, target: target} = ref, opts) do
    with {:object, %Object{} = object} <- {:object, get_object_imp(state, target)},
         {:type, %{type: :commit}} <- {:type, object},
         {:old_target_matches?, true} <-
           {:old_target_matches?, old_target_matches?(refs, name, Keyword.get(opts, :old_target))} do
      cover {:ok, %{state | refs: Map.put(refs, name, ref)}}
    else
      {:object, nil} -> cover {:error, :target_not_found, state}
      {:type, _} -> cover {:error, :target_not_commit, state}
      {:old_target_matches?, _} -> cover {:error, :old_target_not_matched, state}
    end
  end

  defp old_target_matches?(_refs, _name, nil), do: cover(true)

  defp old_target_matches?(refs, name, :new), do: not Map.has_key?(refs, name)

  defp old_target_matches?(refs, name, old_target),
    do: match?(%Ref{target: ^old_target}, Map.get(refs, name))

  @impl true
  def handle_delete_ref(%{refs: refs} = state, name, opts) do
    if old_target_matches?(refs, name, Keyword.get(opts, :old_target)) do
      cover {:ok, %{state | refs: Map.delete(refs, name)}}
    else
      cover {:error, :old_target_not_matched, state}
    end
  end

  @impl true
  def handle_get_ref(%{refs: refs} = state, name, _opts) do
    case Map.get(refs, name) do
      %Ref{} = ref -> cover {:ok, ref, state}
      nil -> cover {:error, :not_found, state}
    end
  end
end
