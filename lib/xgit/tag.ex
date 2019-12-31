defmodule Xgit.Tag do
  @moduledoc ~S"""
  Represents a git `tag` object in memory.
  """
  alias Xgit.ContentSource
  alias Xgit.Object
  alias Xgit.ObjectId
  alias Xgit.ObjectType
  alias Xgit.PersonIdent

  use Xgit.ObjectType

  import Xgit.Util.ForceCoverage
  import Xgit.Util.ParseHeader, only: [next_header: 1]

  @typedoc ~S"""
  This struct describes a single `tag` object so it can be manipulated in memory.

  ## Struct Members

  * `:object`: (`Xgit.ObjectId`) object referenced by this tag
  * `:type`: (`Xgit.ObjectType`) type of the target object
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
          tagger: PersonIdent.t() | nil,
          message: [byte]
        }

  @enforce_keys [:object, :type, :name, :message]
  defstruct [:object, :type, :name, :message, tagger: nil]

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
      (tagger == nil || PersonIdent.valid?(tagger)) &&
      not Enum.empty?(message)
  end

  def valid?(_), do: cover(false)

  @typedoc ~S"""
  Error response codes returned by `from_object/1`.
  """
  @type from_object_reason :: :not_a_tag | :invalid_tag

  @doc ~S"""
  Renders a tag structure from an `Xgit.Object`.

  ## Return Values

  `{:ok, tag}` if the object contains a valid `tag` object.

  `{:error, :not_a_tag}` if the object contains an object of a different type.

  `{:error, :invalid_tag}` if the object says that is of type `tag`, but
  can not be parsed as such.
  """
  @spec from_object(object :: Object.t()) :: {:ok, tag :: t} | {:error, from_object_reason}
  def from_object(object)

  def from_object(%Object{type: :tag, content: content} = _object) do
    content
    |> ContentSource.stream()
    |> Enum.to_list()
    |> from_object_internal()
  end

  def from_object(%Object{} = _object), do: cover({:error, :not_a_tag})

  defp from_object_internal(data) do
    with {:object, {'object', object_id_str, data}} <- {:object, next_header(data)},
         {:object_id, {object_id, []}} <- {:object_id, ObjectId.from_hex_charlist(object_id_str)},
         {:type_str, {'type', type_str, data}} <- {:type_str, next_header(data)},
         {:type, type} when is_object_type(type) <- {:type, ObjectType.from_bytelist(type_str)},
         {:name, {'tag', [_ | _] = name, data}} <- {:name, next_header(data)},
         {:tagger_id, tagger, data} <- optional_tagger(data),
         message when is_list(message) <- drop_if_lf(data) do
      # TO DO: Support signatures and other extensions.
      # https://github.com/elixir-git/xgit/issues/202
      cover {:ok,
             %__MODULE__{
               object: object_id,
               type: type,
               name: name,
               tagger: tagger,
               message: message
             }}
    else
      _ -> cover {:error, :invalid_tag}
    end
  end

  defp optional_tagger(data) do
    with {:tagger, {'tagger', tagger_str, data}} <- {:tagger, next_header(data)},
         {:tagger_id, %PersonIdent{} = tagger} <-
           {:tagger_id, PersonIdent.from_byte_list(tagger_str)} do
      cover {:tagger_id, tagger, data}
    else
      {:tagger, :no_header_found} ->
        cover {:tagger_id, nil, data}

      {:tagger_id, x} ->
        cover {:tagger_error, x}
    end
  end

  defp drop_if_lf([10 | data]), do: cover(data)
  defp drop_if_lf([]), do: cover([])
  defp drop_if_lf(_), do: cover(:error)

  @doc ~S"""
  Renders this tag structure into a corresponding `Xgit.Object`.

  If the tag structure is not valid, will raise `ArgumentError`.
  """
  @spec to_object(commit :: t) :: Object.t()
  def to_object(commit)

  def to_object(
        %__MODULE__{
          object: object_id,
          type: object_type,
          name: tag_name,
          message: message
        } = tag
      ) do
    unless valid?(tag) do
      raise ArgumentError, "Xgit.Tag.to_object/1: tag is not valid"
    end

    rendered_tagger =
      case tag.tagger do
        nil -> cover ''
        %PersonIdent{} = tagger -> cover 'tagger #{PersonIdent.to_external_string(tagger)}\n'
      end

    rendered_tag =
      'object #{object_id}\n' ++
        'type #{object_type}\n' ++
        'tag #{tag_name}\n' ++
        rendered_tagger ++
        '\n' ++
        message

    # TO DO: Support signatures and other extensions.
    # https://github.com/elixir-git/xgit/issues/202

    cover %Object{
      type: :tag,
      content: rendered_tag,
      size: Enum.count(rendered_tag),
      id: ObjectId.calculate_id(rendered_tag, :tag)
    }
  end
end
