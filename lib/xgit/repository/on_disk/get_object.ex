defmodule Xgit.Repository.OnDisk.GetObject do
  @moduledoc false
  # Implements Xgit.Repository.OnDisk.handle_get_object/2.

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Util.RawParseUtils
  alias Xgit.Util.UnzipStream

  defmodule LooseObjectContentSource do
    @moduledoc false
    # Implements `Xgit.Core.ContentSource` to read content from a loose object.

    import Xgit.Util.ForceCoverage

    @type t :: %__MODULE__{path: Path.t(), size: non_neg_integer}

    @enforce_keys [:path, :size]
    defstruct [:path, :size]

    defimpl Xgit.Core.ContentSource do
      alias Xgit.Repository.OnDisk.GetObject.LooseObjectContentSource, as: LCS
      @impl true
      def length(%LCS{size: size}), do: cover(size)

      @impl true
      def stream(%LCS{path: path}) do
        path
        |> File.stream!([:binary])
        |> UnzipStream.unzip()
        |> Stream.drop_while(&(&1 != 0))
        |> Stream.drop(1)
      end
    end
  end

  @spec handle_get_object(state :: any, object_id :: ObjectId.t()) ::
          {:ok, object :: Object.t(), state :: any}
          | {:error, :not_found | :invalid_object, state :: any}
  def handle_get_object(%{git_dir: git_dir} = state, object_id) do
    # Currently only checks for loose objects.
    # TO DO: Look for object in packs.
    # https://github.com/elixir-git/xgit/issues/52

    case find_loose_object(git_dir, object_id) do
      %Object{} = object -> {:ok, object, state}
      {:error, :not_found} -> {:error, :not_found, state}
      {:error, :invalid_object} -> {:error, :invalid_object, state}
    end
  end

  defp find_loose_object(git_dir, object_id) do
    loose_object_path =
      Path.join([
        git_dir,
        "objects",
        String.slice(object_id, 0, 2),
        String.slice(object_id, 2, 38)
      ])

    with {:exists?, true} <- {:exists?, File.regular?(loose_object_path)},
         {:header, type, length} <- read_loose_object_prefix(loose_object_path) do
      loose_file_to_object(type, length, object_id, loose_object_path)
    else
      {:exists?, false} -> cover {:error, :not_found}
      :invalid_header -> cover {:error, :invalid_object}
    end
  end

  defp read_loose_object_prefix(path) do
    path
    |> File.stream!([:binary], 100)
    |> UnzipStream.unzip()
    |> Stream.take(100)
    |> Stream.take_while(&(&1 != 0))
    |> Enum.to_list()
    |> Enum.split_while(&(&1 != ?\s))
    |> parse_prefix_and_length()
  rescue
    ErlangError -> cover :invalid_header
  end

  @known_types ['blob', 'tag', 'tree', 'commit']
  @type_to_atom %{'blob' => :blob, 'tag' => :tag, 'tree' => :tree, 'commit' => :commit}

  defp parse_prefix_and_length({type, length}) when type in @known_types,
    do: parse_length(@type_to_atom[type], length)

  defp parse_prefix_and_length(_), do: cover(:invalid_header)

  defp parse_length(_type, ' '), do: cover(:invalid_header)

  defp parse_length(type, [?\s | length]) do
    case RawParseUtils.parse_base_10(length) do
      {length, []} when is_integer(length) and length >= 0 -> {:header, type, length}
      _ -> cover :invalid_header
    end
  end

  defp parse_length(_type, _length), do: cover(:invalid_header)

  defp loose_file_to_object(type, length, object_id, path)
       when is_atom(type) and is_integer(length) do
    %Object{
      type: type,
      size: length,
      id: object_id,
      content: %__MODULE__.LooseObjectContentSource{size: length, path: path}
    }
  end
end
