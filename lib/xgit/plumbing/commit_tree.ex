defmodule Xgit.Plumbing.CommitTree do
  @moduledoc ~S"""
  Creates a new commit object based on the provided tree object.

  Analogous to
  [`git commit-tree`](https://git-scm.com/docs/git-commit-tree).
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.Commit
  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Core.PersonIdent
  alias Xgit.Core.Tree
  alias Xgit.Repository

  @typedoc ~S"""
  Reason codes that can be returned by `run/2`.
  """
  @type reason ::
          :invalid_repository
          | :invalid_tree
          | :invalid_parents
          | :invalid_message
          | :invalid_author
          | :invalid_committer
          | Repository.put_loose_object_reason()

  # TODO: More to come, I'm sure.

  @doc ~S"""
  Creates a new commit object based on the provided tree object and parent commits.

  A commit object may have any number of parents. With exactly one parent, it is an
  ordinary commit. Having more than one parent makes the commit a merge between
  several lines of history. Initial (root) commits have no parents.

  ## Parameters

  `repository` is the `Xgit.Repository` (PID) to search for the object.

  ## Options

  `tree`: (`Xgit.Core.ObjectId`, required) ID of tree object

  `parents`: (list of `Xgit.Core.ObjectId`) parent commit object IDs

  `message`: (byte list, required) commit message

  `author`: (`Xgit.Core.PersonIdent`, required) author name, email, timestamp

  `committer`: (`Xgit.Core.PersonIdent`) committer name, email timestamp
  (defaults to `author` if not specified)

  ## Return Value

  `{:ok, object_id}` with the object ID for the commit that was generated.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository` process.

  `{:error, :invalid_tree}` if the `:tree` option refers to a tree that
  does not exist.

  `{:error, :invalid_parents}` if the `:parents` option is not a list.

  `{:error, :invalid_message}` if the `:message` option isn't a valid byte string.

  `{:error, :invalid_author}` if the `:author` option isn't a valid `PersonIdent` struct.

  `{:error, :invalid_committer}` if the `:committer` option isn't a valid `PersonIdent` struct.

  Reason codes may also come from the following functions:

  * **TODO**: Identify other reason codes and functions that contribute reasons.
  """
  @spec run(repository :: Repository.t(),
          tree: ObjectId.t(),
          parents: [ObjectId.t()],
          message: [byte],
          author: PersonIdent.t(),
          committer: PersonIdent.t()
        ) ::
          {:ok, object_id :: ObjectId.t()}
          | {:error, reason :: reason}
  def run(repository, opts \\ []) when is_pid(repository) do
    with {:repository_valid?, true} <- {:repository_valid?, Repository.valid?(repository)},
         {_tree, _parents, _message, _author, _committer} = verified_args <-
           validate_options(repository, opts),
         commit <- make_commit(verified_args),
         %{id: id} = object <- Commit.to_object(commit),
         :ok <- Repository.put_loose_object(repository, object) do
      cover {:ok, id}
    else
      {:repository_valid?, _} -> cover {:error, :invalid_repository}
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp validate_options(repository, opts) do
    with {:ok, tree_id} <- validate_tree(repository, Keyword.get(opts, :tree)),
         {:ok, parent_ids} <- validate_parents(repository, Keyword.get(opts, :parents)),
         {:ok, message} <- validate_message(Keyword.get(opts, :message)),
         {:ok, author} <- validate_person_ident(Keyword.get(opts, :author), :invalid_author),
         {:ok, committer} <-
           validate_person_ident(Keyword.get(opts, :committer, author), :invalid_committer) do
      cover {tree_id, parent_ids, message, author, committer}
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp validate_tree(repository, tree_id) do
    with true <- ObjectId.valid?(tree_id),
         {:ok, %Object{id: id} = object} <- Repository.get_object(repository, tree_id),
         {:ok, _tree} <- Tree.from_object(object) do
      cover {:ok, id}
    else
      _ -> cover {:error, :invalid_tree}
    end
  end

  defp validate_parents(_repository, nil), do: cover({:ok, []})

  defp validate_parents(repository, parent_ids) when is_list(parent_ids) do
    if Enum.all?(parent_ids, &commit_id_valid?(repository, &1)) do
      cover {:ok, parent_ids}
    else
      cover {:error, :invalid_parent_ids}
    end
  end

  defp validate_parents(_repository, _parents), do: cover({:error, :invalid_parents})

  defp commit_id_valid?(repository, parent_id) do
    with true <- ObjectId.valid?(parent_id),
         {:ok, %Object{type: :commit}} <- Repository.get_object(repository, parent_id) do
      cover true
    else
      _ -> cover false
    end
  end

  defp validate_message(message) when is_list(message) do
    if Enum.all?(message, &is_integer/1) do
      cover {:ok, message}
    else
      cover {:error, :invalid_message}
    end
  end

  defp validate_message(_message), do: cover({:error, :invalid_message})

  defp validate_person_ident(person_ident, invalid_reason) do
    if PersonIdent.valid?(person_ident) do
      cover {:ok, person_ident}
    else
      cover {:error, invalid_reason}
    end
  end

  defp make_commit({tree, parents, message, author, committer} = _verified_args) do
    %Commit{
      tree: tree,
      parents: parents,
      author: author,
      committer: committer,
      message: message
    }
  end
end
