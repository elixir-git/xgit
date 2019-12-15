defprotocol Xgit.ContentSource do
  @moduledoc ~S"""
  Protocol used for reading object content from various sources.
  """

  @typedoc ~S"""
  Any value for which `ContentSource` protocol is implemented.
  """
  @type t :: term

  @doc ~S"""
  Calculate the length (in bytes) of the content.
  """
  @spec length(content :: t) :: non_neg_integer
  def length(content)

  @doc ~S"""
  Return a stream which can be used for reading the content.
  """
  @spec stream(content :: t) :: Enumerable.t()
  def stream(content)
end

defimpl Xgit.ContentSource, for: List do
  @impl true
  def length(list), do: Enum.count(list)

  @impl true
  def stream(list), do: list
end

defimpl Xgit.ContentSource, for: BitString do
  @impl true
  def length(s), do: byte_size(s)

  @impl true
  def stream(s), do: :binary.bin_to_list(s)
end
