defmodule Xgit.Commit do
  @moduledoc ~S"""
  Represents a git `commit` object in memory.
  """
  alias Xgit.ContentSource
  alias Xgit.Object
  alias Xgit.ObjectId
  alias Xgit.PersonIdent

  import Xgit.Util.ForceCoverage
  import Xgit.Util.ParseHeader, only: [next_header: 1]

  @typedoc ~S"""
  This struct describes a single `commit` object so it can be manipulated in memory.

  ## Struct Members

  * `:tree`: (`Xgit.ObjectId`) tree referenced by this commit
  * `:parents`: (list of `Xgit.ObjectId`) parent(s) of this commit
  * `:author`: (`Xgit.PersonIdent`) author of this commit
  * `:committer`: (`Xgit.PersonIdent`) committer for this commit
  * `:message`: (bytelist) user-entered commit message (encoding unspecified)

  **TO DO:** Support signatures and other extensions.
  https://github.com/elixir-git/xgit/issues/202
  """
  @type t :: %__MODULE__{
          tree: ObjectId.t(),
          parents: [ObjectId.t()],
          author: PersonIdent.t(),
          committer: PersonIdent.t(),
          message: [byte]
        }

  @enforce_keys [:tree, :author, :committer, :message]
  defstruct [:tree, :author, :committer, :message, parents: []]

  @doc ~S"""
  Return `true` if the value is a commit struct that is valid.
  """
  @spec valid?(commit :: any) :: boolean
  def valid?(commit)

  def valid?(%__MODULE__{
        tree: tree,
        parents: parents,
        author: %PersonIdent{} = author,
        committer: %PersonIdent{} = committer,
        message: message
      })
      when is_binary(tree) and is_list(parents) and is_list(message) do
    ObjectId.valid?(tree) &&
      Enum.all?(parents, &ObjectId.valid?(&1)) &&
      PersonIdent.valid?(author) &&
      PersonIdent.valid?(committer) &&
      not Enum.empty?(message)
  end

  def valid?(_), do: cover(false)

  @typedoc ~S"""
  Error response codes returned by `from_object/1`.
  """
  @type from_object_reason :: :not_a_commit | :invalid_commit

  @doc ~S"""
  Renders a commit structure from an `Xgit.Object`.

  ## Return Values

  `{:ok, commit}` if the object contains a valid `commit` object.

  `{:error, :not_a_commit}` if the object contains an object of a different type.

  `{:error, :invalid_commit}` if the object says that is of type `commit`, but
  can not be parsed as such.
  """
  @spec from_object(object :: Object.t()) :: {:ok, commit :: t} | {:error, from_object_reason}
  def from_object(object)

  def from_object(%Object{type: :commit, content: content} = _object) do
    content
    |> ContentSource.stream()
    |> Enum.to_list()
    |> from_object_internal()
  end

  def from_object(%Object{} = _object), do: cover({:error, :not_a_commit})

  defp from_object_internal(data) do
    with {:tree, {'tree', tree_id_str, data}} <- {:tree, next_header(data)},
         {:tree_id, {tree_id, []}} <- {:tree_id, ObjectId.from_hex_charlist(tree_id_str)},
         {:parents, {parents, data}} when is_list(data) <-
           {:parents, read_parents(data, [])},
         {:author, {'author', author_str, data}} <- {:author, next_header(data)},
         {:author_id, %PersonIdent{} = author} <-
           {:author_id, PersonIdent.from_byte_list(author_str)},
         {:committer, {'committer', committer_str, data}} <-
           {:committer, next_header(data)},
         {:committer_id, %PersonIdent{} = committer} <-
           {:committer_id, PersonIdent.from_byte_list(committer_str)},
         message when is_list(message) <- drop_if_lf(data) do
      # TO DO: Support signatures and other extensions.
      # https://github.com/elixir-git/xgit/issues/202
      cover {:ok,
             %__MODULE__{
               tree: tree_id,
               parents: parents,
               author: author,
               committer: committer,
               message: message
             }}
    else
      _ -> cover {:error, :invalid_commit}
    end
  end

  defp read_parents(data, parents_acc) do
    with {'parent', parent_id, next_data} <- next_header(data),
         {:parent_id, {parent_id, []}} <- {:parent_id, ObjectId.from_hex_charlist(parent_id)} do
      read_parents(next_data, [parent_id | parents_acc])
    else
      {:parent_id, _} -> cover :error
      _ -> cover {Enum.reverse(parents_acc), data}
    end
  end

  defp drop_if_lf([10 | data]), do: cover(data)
  defp drop_if_lf([]), do: cover([])
  defp drop_if_lf(_), do: cover(:error)

  @doc ~S"""
  Renders this commit structure into a corresponding `Xgit.Object`.

  If duplicate parents are detected, they will be silently de-duplicated.

  If the commit structure is not valid, will raise `ArgumentError`.
  """
  @spec to_object(commit :: t) :: Object.t()
  def to_object(commit)

  def to_object(
        %__MODULE__{
          tree: tree,
          parents: parents,
          author: %PersonIdent{} = author,
          committer: %PersonIdent{} = committer,
          message: message
        } = commit
      ) do
    unless valid?(commit) do
      raise ArgumentError, "Xgit.Commit.to_object/1: commit is not valid"
    end

    rendered_parents =
      parents
      |> Enum.uniq()
      |> Enum.flat_map(&'parent #{&1}\n')

    rendered_commit =
      'tree #{tree}\n' ++
        rendered_parents ++
        'author #{PersonIdent.to_external_string(author)}\n' ++
        'committer #{PersonIdent.to_external_string(committer)}\n' ++
        '\n' ++
        message

    # TO DO: Support signatures and other extensions.
    # https://github.com/elixir-git/xgit/issues/202

    %Object{
      type: :commit,
      content: rendered_commit,
      size: Enum.count(rendered_commit),
      id: ObjectId.calculate_id(rendered_commit, :commit)
    }
  end
end
