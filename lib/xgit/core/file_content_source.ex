defmodule Xgit.Core.FileContentSource do
  @moduledoc ~S"""
  Implements `Xgit.Core.ContentSource` to read content from a file on disk.
  """

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  Describes a file on disk which will be used for reading content.
  """
  @type t :: %__MODULE__{
          path: Path.t(),
          size: non_neg_integer | :file_not_found
        }

  @enforce_keys [:path, :size]
  defstruct [:path, :size]

  @doc ~S"""
  Creates an `Xgit.Core.FileContentSource` for a file on disk.
  """
  @spec new(path :: Path.t()) :: t
  def new(path) when is_binary(path) do
    size =
      case File.stat(path) do
        {:ok, %File.Stat{size: size}} -> cover size
        _ -> cover :file_not_found
      end

    %__MODULE__{path: path, size: size}
  end

  defimpl Xgit.Core.ContentSource do
    alias Xgit.Core.FileContentSource, as: FCS
    @impl true
    def length(%FCS{size: :file_not_found}), do: raise("file not found")
    def length(%FCS{size: size}), do: cover(size)

    @impl true
    def stream(%FCS{size: :file_not_found}), do: raise("file not found")
    def stream(%FCS{path: path}), do: File.stream!(path, [:charlist], 2048)
  end
end
