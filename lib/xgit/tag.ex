defmodule Xgit.Tag do
  @moduledoc ~S"""
  Represents a git `tag` object in memory.
  """
  alias Xgit.ObjectId
  alias Xgit.PersonIdent

  use Xgit.ObjectType

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  This struct describes a single `tag` object so it can be manipulated in memory.

  ## Struct Members

  * `:object`: (`Xgit.ObjectId`) object referenced by this tag
  * `:type`: ('Xgit.ObjectType`) type of the target object
  * `:name`: (bytelist) name of the tag
  * `:tagger`: (`Xgit.PersonIdent`) person who created the tag
  * `:message`: (bytelist) user-entered tag message (encoding unspecified)

  **TO DO:** Support signatures and other extensions.
  https://github.com/elixir-git/xgit/issues/202
  """
  @type t :: %__MODULE__{
          object: ObjectId.t(),
          type: ObjectType.t(),
          name: [byte],
          tagger: PersonIdent.t(),
          message: [byte]
        }

  @enforce_keys [:object, :type, :name, :tagger, :message]
  defstruct [:object, :type, :name, :tagger, :message]

  @doc ~S"""
  Return `true` if the value is a tag struct that is valid.
  """
  @spec valid?(tag :: any) :: boolean
  def valid?(tag)

  def valid?(%__MODULE__{
        object: object_id,
        type: object_type,
        name: name,
        tagger: tagger,
        message: message
      })
      when is_binary(object_id) and is_object_type(object_type) and is_list(name) and
             is_list(message) do
    ObjectId.valid?(object_id) &&
      not Enum.empty?(name) &&
      PersonIdent.valid?(tagger) &&
      not Enum.empty?(message)
  end

  def valid?(_), do: cover(false)
end
