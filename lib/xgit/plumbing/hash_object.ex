defmodule Xgit.Plumbing.HashObject do
  @moduledoc ~S"""
  Computes an object ID and optionally writes that into the repository's object store.

  Analogous to [`git hash-object`](https://git-scm.com/docs/git-hash-object).
  """

  alias Xgit.Core.ContentSource
  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Core.ObjectType
  alias Xgit.Core.ValidateObject
  alias Xgit.Repository

  @doc ~S"""
  Computes an object ID and optionally writes that into the repository's object store.

  ## Parameters

  `content` describes how this function should obtain the content.
  (See `Xgit.Core.ContentSource`.)

  ## Options

  `:type`: the object's type
    * Type: `Xgit.Core.ObjectType`
    * Default: `:blob`
    * See [`-t` option on `git hash-object`](https://git-scm.com/docs/git-hash-object#Documentation/git-hash-object.txt--tlttypegt).

  `:validate?`: `true` to verify that the object is valid for `:type`
    * Type: boolean
    * Default: `true`
    * This is the inverse of the [`--literally` option on `git hash-object`](https://git-scm.com/docs/git-hash-object#Documentation/git-hash-object.txt---literally).

  `:repo`: where the content should be stored
    * Type: `Xgit.Repository` (PID)
    * Default: `nil`

  `:write?`: `true` to write the object into the repository
    * Type: boolean
    * Default: `false`
    * This option is meaningless if `:repo` is not specified.
    * See [`-w` option on `git hash-object`](https://git-scm.com/docs/git-hash-object#Documentation/git-hash-object.txt--w).

  **TO DO:** There is no support, at present, for filters as defined in a
  `.gitattributes` file. See [issue #18](https://github.com/elixir-git/xgit/issues/18).

  ## Return Value

  `{:ok, object_id}` if the object could be validated and assigned an ID.
  `{:error, "reason"}` if unable.
  """
  @spec run(content :: ContentSource.t(), type: ObjectType.t() | nil) ::
          {:ok, ObjectID.t()} | {:error, reason :: String.t()}
  def run(content, opts \\ []) when not is_nil(content) and is_list(opts) do
    %{type: type, validate?: validate?, repo: repo, write?: write?} = validate_options(opts)

    %Object{content: content, type: type}
    |> apply_filters(repo)
    |> annotate_with_size()
    |> assign_object_id()
    |> validate_content(validate?)
    |> maybe_write_to_repo(repo, write?)
    |> result(opts)
  end

  defp validate_options(opts) do
    type = Keyword.get(opts, :type, :blob)

    unless ObjectType.valid?(type) do
      raise ArgumentError, "Xgit.Plumbing.HashObject.run/2: type #{inspect(type)} is invalid"
    end

    validate? = Keyword.get(opts, :validate?, true)

    unless is_boolean(validate?) do
      raise ArgumentError,
            "Xgit.Plumbing.HashObject.run/2: validate? #{inspect(validate?)} is invalid"
    end

    repo = Keyword.get(opts, :repo)

    unless repo == nil or Repository.valid?(repo) do
      raise ArgumentError, "Xgit.Plumbing.HashObject.run/2: repo #{inspect(repo)} is invalid"
    end

    write? = Keyword.get(opts, :write?, false)

    unless is_boolean(write?) do
      raise ArgumentError,
            "Xgit.Plumbing.HashObject.run/2: write? #{inspect(write?)} is invalid"
    end

    if write? and repo == nil do
      raise ArgumentError,
            "Xgit.Plumbing.HashObject.run/2: write?: true requires a repo to be specified"
    end

    %{type: type, validate?: validate?, repo: repo, write?: write?}
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

  defp validate_content(%Object{type: :blob} = object, _validate?), do: {:ok, object}
  defp validate_content(object, false = _validate?), do: {:ok, object}

  defp validate_content(%Object{content: content} = object, _validate?) when is_list(content) do
    case ValidateObject.check(object) do
      :ok -> {:ok, object}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_content(%Object{content: content} = object, _validate?) do
    validate_content(
      %{object | content: content |> ContentSource.stream() |> Enum.to_list() |> Enum.concat()},
      true
    )
  end

  defp assign_object_id(%Object{content: content, type: type} = object),
    do: %{object | id: ObjectId.calculate_id(content, type)}

  defp maybe_write_to_repo({:ok, object}, _repo, false = _write?), do: {:ok, object}

  defp maybe_write_to_repo({:ok, object}, repo, true = _write?) do
    case Repository.put_loose_object(repo, object) do
      :ok -> {:ok, object}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_write_to_repo({:error, reason}, _repo, _write?), do: {:error, reason}

  defp result({:ok, %Object{id: id}}, _opts), do: {:ok, id}
  defp result({:error, reason}, _opts), do: {:error, reason}
end
