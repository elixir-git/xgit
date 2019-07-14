defmodule Xgit.Core.Object do
  @moduledoc ~S"""
  Describes a single object stored (or about to be stored) in a git repository.

  This struct is constructed, modified, and shared as a working description of
  how to find and describe an object before it gets written to a repository.
  """
  use Xgit.Core.ObjectType

  alias Xgit.Core.ContentSource

  @typedoc ~S"""
  This struct describes a single object stored or about to be stored in a git
  repository.

  ## Struct Members

  * `:type`: the object's type (`:blob`, `:tree`, `:commit`, or `:tag`)
  * `:content`: how to obtain the content (see `Xgit.Core.ContentSource`)
  """
  @type t :: %__MODULE__{
          type: ObjectType.t(),
          content: ContentSource.t()
        }

  defstruct [:type, :content]

  @doc ~S"""
  Constructs a new `Object`.

  ## Options

  `:type`: the object's type (default: `:blob`)
  `:content`: how to obtain the content (see `Xgit.Core.ContentSource`)
  """
  def new(opts) when is_list(opts) do
    type = Keyword.get(opts, :type, :blob)

    unless is_object_type(type) do
      raise ArgumentError, "Xgit.Core.Object.new/1: type #{inspect(type)} is invalid"
    end

    content = Keyword.get(opts, :content)

    if is_nil(content) do
      raise ArgumentError, "Xgit.Core.Object.new/1: :content is missing"
    end

    %__MODULE__{type: type, content: content}
  end
end
