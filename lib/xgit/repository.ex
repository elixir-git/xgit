defmodule Xgit.Repository do
  @moduledoc ~S"""
  Represents a git repository.

  Create a repository by calling the `start_link` function on one of the modules
  that implements `Xgit.Repository.Storage`. The resulting PID can be used when
  calling functions in this module and `Xgit.Repository.Plumbing`.

  The functions implemented in this module correspond to the "porcelain" commands
  implemented by command-line git.

  (As of this writing, relatively few of the porcelain commands are implemented.)
  """
  import Xgit.Util.ForceCoverage

  alias Xgit.Object
  alias Xgit.ObjectId
  alias Xgit.PersonIdent
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

  @typedoc ~S"""
  Reason codes that can be returned by `tag/4`.
  """
  @type tag_reason :: Storage.put_ref_reason()

  @doc ~S"""
  Create a tag object.

  Analogous to the _create_ form of [`git tag`](https://git-scm.com/docs/git-tag).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  `tag_name` (`String`) is the name to give to the new tag.

  `object` (`Xgit.ObjectId`) is the object ID to be pointed to by this tag
  (typically a `commit` object).

  ## Options

  `annotated?`: (boolean) true to create an annotated tag (default: `false` unless `message` is specified)

  `force?`: (boolean) true to replace an existing tag (default: `false`)

  `message`: (`String` or bytelist) message to associate with the tag.
  * Must be present and non-empty if `:annotated?` is `true`.
  * Implies `annotated?: true`.

  `tagger`: (`Xgit.PersonIdent`, required if annotated) tagger name, email, timestamp

  ## Return Value

  `:ok` if created successfully.

  `{:error, reason}` if unable. Reason codes may come from `Xgit.Repository.Storage.put_ref/3`.

  TO DO: Support GPG signatures. https://github.com/elixir-git/xgit/issues/202
  """
  @spec tag(repository :: t, tag_name :: String.t(), object :: ObjectId.t(),
          annotated?: boolean,
          force?: boolean,
          message: [byte] | String.t(),
          tagger: PersonIdent.t()
        ) :: :ok | {:error, reason :: tag_reason}
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
      create_annotated_tag(
        repository,
        tag_name,
        object,
        force?,
        message,
        tagger_from_tag_options(options)
      )
    else
      create_lightweight_tag(repository, tag_name, object, force?)
    end
  end

  defp force_from_tag_options(options) do
    case Keyword.get(options, :force?, false) do
      false ->
        cover false

      true ->
        cover true

      invalid ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: force? #{inspect(invalid)} is invalid"
    end
  end

  defp message_from_tag_options(options) do
    case Keyword.get(options, :message) do
      nil ->
        cover nil

      "" ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: message must be non-empty if present"

      message when is_binary(message) ->
        String.to_charlist(message)

      [_ | _] = message ->
        cover message

      [] ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: message must be non-empty if present"

      invalid ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: message #{inspect(invalid)} is invalid"
    end
  end

  defp annotated_from_tag_options(options, message) do
    case Keyword.get(options, :annotated?, message != nil) do
      false ->
        if message == nil do
          cover false
        else
          raise ArgumentError,
                "Xgit.Repository.tag/4: annotated?: false can not be specified when message is present"
        end

      true ->
        if message == nil do
          raise ArgumentError,
                "Xgit.Repository.tag/4: annotated?: true can not be specified without message"
        else
          cover true
        end

      invalid ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: annotated? #{inspect(invalid)} is invalid"
    end
  end

  defp tagger_from_tag_options(options) do
    tagger = Keyword.get(options, :tagger)

    cond do
      tagger == nil ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: tagger must be specified for an annotated tag"

      PersonIdent.valid?(tagger) ->
        cover tagger

      true ->
        raise ArgumentError,
              "Xgit.Repository.tag/4: tagger #{inspect(tagger)} is invalid"
    end
  end

  defp create_annotated_tag(repository, tag_name, object, force?, message, tagger) do
    with :ok <- check_existing_ref(repository, tag_name, force?),
         {:ok, %Object{type: target_type}} <- Storage.get_object(repository, object),
         tag <- %Tag{
           object: object,
           type: target_type,
           name: String.to_charlist(tag_name),
           tagger: tagger,
           message: ensure_trailing_newline(message)
         },
         %Object{id: tag_id} = tag_object <- Tag.to_object(tag),
         :ok <- Storage.put_loose_object(repository, tag_object) do
      ref = %Ref{name: "refs/tags/#{tag_name}", target: tag_id}
      Storage.put_ref(repository, ref, opts_for_force(force?))
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp check_existing_ref(_repository, _tag_name, true), do: cover(:ok)

  defp check_existing_ref(repository, tag_name, false) do
    case Storage.get_ref(repository, "refs/tags/#{tag_name}") do
      {:ok, %Ref{}} -> cover {:error, :old_target_not_matched}
      {:error, :not_found} -> cover :ok
    end
  end

  defp ensure_trailing_newline(message) do
    if List.last(message) == 10 do
      cover(message)
    else
      cover(message ++ '\n')
    end
  end

  defp create_lightweight_tag(repository, tag_name, object, force?) do
    ref = %Ref{name: "refs/tags/#{tag_name}", target: object}
    Storage.put_ref(repository, ref, opts_for_force(force?))
  end

  defp opts_for_force(true), do: cover(follow_link?: false)
  defp opts_for_force(false), do: cover(follow_link?: false, old_target: :new)
end
