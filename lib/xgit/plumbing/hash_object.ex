defmodule Xgit.Plumbing.HashObject do
  @moduledoc ~S"""
  Computes an object ID and optionally writes that into the repository's object store.

  Analogous to [`git hash-object`](https://git-scm.com/docs/git-hash-object).
  """

  alias Xgit.Core.ContentSource
  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Core.ObjectType

  @doc ~S"""
  Computes an object ID and optionally writes that into the repository's object store.

  ## Parameters

  `content` describes how this function should obtain the content.
  (See `Xgit.Core.ContentSource`.)

  ## Options

  `:type`: the object's type
    * Type: `Xgit.Core.ObjectType`
    * Default: `:blob`
    * See [`-t` option on `git hash-object`](https://git-scm.com/docs/git-hash-object#Documentation/git-hash-object.txt--tlttypegt)

  ## Return Value

  The object's ID. (See `Xgit.Core.ObjectId`.)
  """
  @spec run(content :: ContentSource.t(), type: ObjectType.t() | nil) :: ObjectID.t()
  def run(content, opts \\ []) when not is_nil(content) and is_list(opts) do
    type = Keyword.get(opts, :type, :blob)

    unless ObjectType.valid?(type) do
      raise ArgumentError, "Xgit.Plumbing.HashObject.run/2: type #{inspect(type)} is invalid"
    end

    repo = nil
    # Keyword.get(opts, :repository)

    %Object{content: content, type: Keyword.get(opts, :type, :blob)}
    |> apply_filters(repo)
    |> annotate_with_size()
    |> validate_content()
    |> assign_object_id()
    |> maybe_write_to_repo(opts)
    |> result(opts)
  end

  defp apply_filters(object, _repository) do
    # TO DO: Implement filters as described in attributes (for instance,
    # end-of-line conversion). I expect this to happen by replacing the
    # ContentSource implementation with another implementation that would
    # perform the content remapping. For now, always a no-op.

    # https://github.com/elixir-git/xgit/issues/18

    object
  end

  defp annotate_with_size(%Object{content: content} = object),
    do: %{object | size: ContentSource.length(content)}

  defp validate_content(object) do
    # TO DO: Add content validation per object type.
    # Allow this to be bypassed.
    object
  end

  defp assign_object_id(%Object{content: content, type: type} = object),
    do: %{object | id: ObjectId.calculate_id(content, type)}

  defp maybe_write_to_repo(object, _opts) do
    # TO DO: Pass the object through to repo to write it to disk.
    object
  end

  defp result(%Object{id: id}, _opts), do: id
end
