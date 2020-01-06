defmodule Xgit.Repository do
  @moduledoc ~S"""
  Represents a git repository.

  Create a repository by calling the `start_link` function on one of the modules
  that implements `Xgit.Repository.Storage`. The resulting PID can be used when
  calling functions in this module and `Xgit.Repository.Plumbing`.

  The functions implemented in this module correspond to the "plumbing" commands
  implemented by command-line git.
  """
  alias Xgit.ObjectId
  alias Xgit.Ref
  alias Xgit.Repository.Storage
  alias Xgit.Tag

  @typedoc ~S"""
  The process ID for an `Xgit.Repository` process.

  This is the same process ID returned from the `start_link` function of any
  module that implements `Xgit.Repository.Storage`.
  """
  @type t :: pid

  @doc ~S"""
  Returns `true` if the argument is a PID representing a valid `Xgit.Repository` process.
  """
  @spec valid?(repository :: term) :: boolean
  defdelegate valid?(repository), to: Storage

  ## -- Tags --

  @doc ~S"""
  Create a tag object.

  Analogous to the _create_ form of [`git tag`](https://git-scm.com/docs/git-tag).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  `tag_name` (String.t) is the name to give to the new tag.

  `object` (ObjectId.t) is the object ID to be pointed to by this tag (typically a `commit` object).

  ## Options

  `annotated?`: (boolean) true to create an annotated tag (default: `false` unless `message` is specified)

  `force?`: (boolean) true to replace an existing tag (default: `false`)

  `message`: (bytelist) message to associate with the tag.
  * Must be non-empty if `:annotated?` is `true`.
  * Implies `annotated?: true`.

  ## Return Value

  `:ok` if created successfully.

  `{:error, reason}` if unable.

  TO DO: Specify reason codes.

  TO DO: Support GPG signatures
  """
  @spec tag(repository :: t, tag_name :: String.t(), object :: ObjectId.t(),
          annotated?: boolean,
          force?: boolean,
          message: [byte]
        ) :: :ok
  def tag(repository, tag_name, object, options \\ [])
      when is_pid(repository) and is_binary(tag_name) and is_binary(object) and is_list(options) do
    repository = Storage.assert_valid(repository)

    unless Tag.valid_name?(String.to_charlist(tag_name)) do
      raise ArgumentError,
            ~s(Xgit.Repository.tag/4: tag_name "#{tag_name}" is invalid)
    end

    unless ObjectId.valid?(object) do
      raise ArgumentError,
            "Xgit.Repository.tag/4: object #{inspect(object)} is invalid"
    end

    force? = force_from_tag_options(options)
    message = message_from_tag_options(options)
    annotated? = annotated_from_tag_options(options, message)

    if annotated? do
      create_annotated_tag(repository, tag_name, object, force?, message)
    else
      create_lightweight_tag(repository, tag_name, object, force?)
    end
  end

  defp force_from_tag_options(options) do
    case Keyword.get(options, :force?, false) do
      false ->
        false

      true ->
        true

      invalid ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: force? #{inspect(invalid)} is invalid"
    end
  end

  defp message_from_tag_options(options) do
    case Keyword.get(options, :message) do
      nil ->
        nil

      "" ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: message must be non-empty if present"

      message when is_binary(message) ->
        String.to_charlist(message)

      [_ | _] = message ->
        message

      [] ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: message must be non-empty if present"

      invalid ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: message #{inspect(invalid)} is invalid"
    end
  end

  defp annotated_from_tag_options(options, message) do
    case Keyword.get(options, :annotated?, is_list(message)) do
      nil ->
        is_list(message)

      false ->
        if is_list(message) do
          raise ArgumentError,
                "Xgit.Repository.tag/4: annotated?: false can not be specified when message is present"
        else
          false
        end

      true ->
        true

      invalid ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: annotated? #{inspect(invalid)} is invalid"
    end
  end

  defp create_annotated_tag(_repository, _tag_name, _object, _force?, _message) do
    raise "not yet"
  end

  defp create_lightweight_tag(repository, tag_name, object, force?) do
    opts =
      if force? do
        [follow_link?: false]
      else
        [follow_link?: false, old_target: :new]
      end

    ref = %Ref{name: "refs/tags/#{tag_name}", target: object}
    Storage.put_ref(repository, ref, opts)
  end
end
