defmodule Xgit.Core.Commit do
  @moduledoc ~S"""
  Represents a git `commit` object in memory.
  """
  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Core.PersonIdent

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  This struct describes a single `commit` object so it can be manipulated in memory.

  ## Struct Members

  * `:tree`: (`Xgit.Core.ObjectId`) tree referenced by this commit
  * `:parents`: (list of `Xgit.Core.ObjectId`) parent(s) of this commit
  * `:author`: (`Xgit.Core.PersonIdent`) author of this commit
  * `:committer`: (`Xgit.Core.PersonIdent`) committer for this commit
  * `:message`: (bytelist) user-entered commit message (encoding unspecified)
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

  @doc ~S"""
  Renders this commit structure into a corresponding `Xgit.Core.Object`.

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
      raise ArgumentError, "Xgit.Core.Commit.to_object/1: commit is not valid"
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

    %Object{
      type: :commit,
      content: rendered_commit,
      size: Enum.count(rendered_commit),
      id: ObjectId.calculate_id(rendered_commit, :commit)
    }
  end
end
