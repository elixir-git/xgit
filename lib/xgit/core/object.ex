defmodule Xgit.Core.Object do
  @moduledoc ~S"""
  Describes a single object stored (or about to be stored) in a git repository.

  This struct is constructed, modified, and shared as a working description of
  how to find and describe an object before it gets written to a repository.
  """
  use Xgit.Core.ObjectType

  alias Xgit.Core.ContentSource
  alias Xgit.Core.ObjectId

  @typedoc ~S"""
  This struct describes a single object stored or about to be stored in a git
  repository.

  ## Struct Members

  * `:type`: the object's type (`:blob`, `:tree`, `:commit`, or `:tag`)
  * `:content`: how to obtain the content (see `Xgit.Core.ContentSource`)
  * `:size`: size (in bytes) of the object or `:unknown`
  * `:id`: object ID (40 chars hex) of the object or `:unknown`
  """
  @type t :: %__MODULE__{
          type: ObjectType.t(),
          content: ContentSource.t(),
          size: non_neg_integer() | :unknown,
          id: ObjectId.t() | :unknown
        }

  @enforce_keys [:type, :content]
  defstruct [:type, :content, size: :unknown, id: :unknown]
end
