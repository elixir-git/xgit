defmodule Xgit.Repository.Plumbing do
  @moduledoc ~S"""
  Implements the "plumbing"-level commands for a git repository.

  The functions in this module, like the "plumbing" commands in command-line
  git, are typically not of interest to an end-user developer. Instead, these
  are the raw building-block operations that are often composed together to
  make the user-targeted "porcelain" commands.
  """
  use Xgit.FileMode

  import Xgit.Util.ForceCoverage

  alias Xgit.Commit
  alias Xgit.ContentSource
  alias Xgit.DirCache
  alias Xgit.DirCache.Entry, as: DirCacheEntry
  alias Xgit.FilePath
  alias Xgit.Object
  alias Xgit.ObjectId
  alias Xgit.ObjectType
  alias Xgit.PersonIdent
  alias Xgit.Ref
  alias Xgit.Repository.Storage
  alias Xgit.Repository.WorkingTree
  alias Xgit.Repository.WorkingTree.ParseIndexFile
  alias Xgit.Tree

  ## --- Objects ---

  @typedoc ~S"""
  Reason codes that can be returned by `hash_object/2`.
  """
  @type hash_object_reason ::
          Object.check_reason()
          | FilePath.check_path_reason()
          | FilePath.check_path_segment_reason()
          | Storage.put_loose_object_reason()

  @doc ~S"""
  Computes an object ID and optionally writes that into the repository's object store.

  Analogous to [`git hash-object`](https://git-scm.com/docs/git-hash-object).

  ## Parameters

  `content` describes how this function should obtain the content.
  (See `Xgit.ContentSource`.)

  ## Options

  `:type`: the object's type
    * Type: `Xgit.ObjectType`
    * Default: `:blob`
    * See [`-t` option on `git hash-object`](https://git-scm.com/docs/git-hash-object#Documentation/git-hash-object.txt--tlttypegt).

  `:validate?`: `true` to verify that the object is valid for `:type`
    * Type: boolean
    * Default: `true`
    * This is the inverse of the [`--literally` option on `git hash-object`](https://git-scm.com/docs/git-hash-object#Documentation/git-hash-object.txt---literally).

  `:repo`: where the content should be stored
    * Type: `Xgit.Repository.Storage` (PID)
    * Default: `nil`

  `:write?`: `true` to write the object into the repository
    * Type: boolean
    * Default: `false`
    * This option is meaningless if `:repo` is not specified.
    * See [`-w` option on `git hash-object`](https://git-scm.com/docs/git-hash-object#Documentation/git-hash-object.txt--w).

  _TO DO:_ There is no support, at present, for filters as defined in a
  `.gitattributes` file. See [issue #18](https://github.com/elixir-git/xgit/issues/18).

  ## Return Values

  `{:ok, object_id}` if the object could be validated and assigned an ID.

  `{:error, :reason}` if unable. The relevant reason codes may come from:

  * `Xgit.FilePath.check_path/2`
  * `Xgit.FilePath.check_path_segment/2`
  * `Xgit.Object.check/2`
  * `Xgit.Repository.Storage.put_loose_object/2`.
  """
  @spec hash_object(content :: ContentSource.t(),
          type: ObjectType.t(),
          validate?: boolean,
          repo: Storage.t(),
          write?: boolean
        ) ::
          {:ok, object_id :: ObjectId.t()} | {:error, reason :: hash_object_reason}
  def hash_object(content, opts \\ []) when not is_nil(content) and is_list(opts) do
    %{type: type, validate?: validate?, repo: repo, write?: write?} =
      validate_hash_object_options(opts)

    %Object{content: content, type: type}
    |> apply_filters(repo)
    |> annotate_with_size()
    |> assign_object_id()
    |> validate_content(validate?)
    |> maybe_write_to_repo(repo, write?)
    |> hash_object_result(opts)
  end

  defp validate_hash_object_options(opts) do
    type = Keyword.get(opts, :type, :blob)

    unless ObjectType.valid?(type) do
      raise ArgumentError,
            "Xgit.Repository.Plumbing.hash_object/2: type #{inspect(type)} is invalid"
    end

    validate? = Keyword.get(opts, :validate?, true)

    unless is_boolean(validate?) do
      raise ArgumentError,
            "Xgit.Repository.Plumbing.hash_object/2: validate? #{inspect(validate?)} is invalid"
    end

    repo = Keyword.get(opts, :repo)

    unless repo == nil or Storage.valid?(repo) do
      raise ArgumentError,
            "Xgit.Repository.Plumbing.hash_object/2: repo #{inspect(repo)} is invalid"
    end

    write? = Keyword.get(opts, :write?, false)

    unless is_boolean(write?) do
      raise ArgumentError,
            "Xgit.Repository.Plumbing.hash_object/2: write? #{inspect(write?)} is invalid"
    end

    if write? and repo == nil do
      raise ArgumentError,
            "Xgit.Repository.Plumbing.hash_object/2: write?: true requires a repo to be specified"
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
    case Object.check(object) do
      :ok -> cover {:ok, object}
      {:error, reason} -> cover {:error, reason}
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

  defp maybe_write_to_repo({:ok, object}, _repo, false = _write?), do: cover({:ok, object})

  defp maybe_write_to_repo({:ok, object}, repo, true = _write?) do
    case Storage.put_loose_object(repo, object) do
      :ok -> cover {:ok, object}
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp maybe_write_to_repo({:error, reason}, _repo, _write?), do: cover({:error, reason})

  defp hash_object_result({:ok, %Object{id: id}}, _opts), do: cover({:ok, id})
  defp hash_object_result({:error, reason}, _opts), do: cover({:error, reason})

  @typedoc ~S"""
  Reason codes that can be returned by `cat_file/2`.
  """
  @type cat_file_reason :: :invalid_repository | :invalid_object_id | Storage.get_object_reason()

  @doc ~S"""
  Retrieves the content, type, and size information for a single object in a
  repository's object store.

  Analogous to the first form of [`git cat-file`](https://git-scm.com/docs/git-cat-file).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  `object_id` is a string identifying the object.

  ## Return Value

  `{:ok, object}` if the object could be found. `object` is an instance of
  `Xgit.Object` and can be used to retrieve content and other information
  about the underlying git object.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :invalid_object_id}` if `object_id` can't be parsed as a valid git object ID.

  `{:error, :not_found}` if the object does not exist in the database.

  `{:error, :invalid_object}` if object was found, but invalid.
  """
  @spec cat_file(repository :: Storage.t(), object_id :: ObjectId.t()) ::
          {:ok, Object} | {:error, reason :: cat_file_reason}
  def cat_file(repository, object_id) when is_pid(repository) and is_binary(object_id) do
    with {:repository_valid?, true} <- {:repository_valid?, Storage.valid?(repository)},
         {:object_id_valid?, true} <- {:object_id_valid?, ObjectId.valid?(object_id)} do
      Storage.get_object(repository, object_id)
    else
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
      {:object_id_valid?, false} -> cover {:error, :invalid_object_id}
    end
  end

  ## --- Tree Objects ---

  @typedoc ~S"""
  Reason codes that can be returned by `cat_file_tree/2`.
  """
  @type cat_file_tree_reason ::
          :invalid_repository
          | :invalid_object_id
          | Storage.get_object_reason()
          | Tree.from_object_reason()

  @doc ~S"""
  Retrieves a `tree` object from a repository's object store and renders
  it as an `Xgit.Tree` struct.

  Analogous to
  [`git cat-file -p`](https://git-scm.com/docs/git-cat-file#Documentation/git-cat-file.txt--p)
  when the target object is a `tree` object.

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  `object_id` is a string identifying the object.

  ## Return Value

  `{:ok, tree}` if the object could be found and understood as a tree.
  `tree` is an instance of `Xgit.Tree` and can be used to retrieve
  references to the members of that tree.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :invalid_object_id}` if `object_id` can't be parsed as a valid git object ID.

  `{:error, reason}` if otherwise unable. The relevant reason codes may come from:

  * `Xgit.Tree.from_object/1`.
  * `Xgit.Repository.Storage.get_object/2`
  """
  @spec cat_file_tree(repository :: Storage.t(), object_id :: ObjectId.t()) ::
          {:ok, tree :: Tree.t()} | {:error, reason :: cat_file_tree_reason}
  def cat_file_tree(repository, object_id) when is_pid(repository) and is_binary(object_id) do
    with {:repository_valid?, true} <- {:repository_valid?, Storage.valid?(repository)},
         {:object_id_valid?, true} <- {:object_id_valid?, ObjectId.valid?(object_id)},
         {:ok, object} <- Storage.get_object(repository, object_id) do
      Tree.from_object(object)
    else
      {:error, reason} -> cover {:error, reason}
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
      {:object_id_valid?, false} -> cover {:error, :invalid_object_id}
    end
  end

  ## --- Commit Objects ---

  @typedoc ~S"""
  Reason codes that can be returned by `cat_file_commit/2`.
  """
  @type cat_file_commit_reason ::
          :invalid_repository
          | :invalid_object_id
          | Commit.from_object_reason()
          | Storage.get_object_reason()

  @doc ~S"""
  Retrieves a `commit` object from a repository's object store and renders
  it as an `Xgit.Commit` struct.

  Analogous to
  [`git cat-file -p`](https://git-scm.com/docs/git-cat-file#Documentation/git-cat-file.txt--p)
  when the target object is a `commit` object.

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  `object_id` is a string identifying the object.

  ## Return Value

  `{:ok, commit}` if the object could be found and understood as a commit.
  `commit` is an instance of `Xgit.Commit` and can be used to retrieve
  references to the members of that commit.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :invalid_object_id}` if `object_id` can't be parsed as a valid git object ID.

  `{:error, reason}` if otherwise unable. The relevant reason codes may come from:

  * `Xgit.Commit.from_object/1`.
  * `Xgit.Repository.Storage.get_object/2`
  """
  @spec cat_file_commit(repository :: Storage.t(), object_id :: ObjectId.t()) ::
          {:ok, commit :: Commit.t()} | {:error, reason :: cat_file_commit_reason}
  def cat_file_commit(repository, object_id) when is_pid(repository) and is_binary(object_id) do
    with {:repository_valid?, true} <- {:repository_valid?, Storage.valid?(repository)},
         {:object_id_valid?, true} <- {:object_id_valid?, ObjectId.valid?(object_id)},
         {:ok, object} <- Storage.get_object(repository, object_id) do
      Commit.from_object(object)
    else
      {:error, reason} -> cover {:error, reason}
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
      {:object_id_valid?, false} -> cover {:error, :invalid_object_id}
    end
  end

  @typedoc ~S"""
  Reason codes that can be returned by `commit_tree/2`.
  """
  @type commit_tree_reason ::
          :invalid_repository
          | :invalid_tree
          | :invalid_parents
          | :invalid_parent_ids
          | :invalid_message
          | :invalid_author
          | :invalid_committer
          | Storage.put_loose_object_reason()

  @doc ~S"""
  Creates a new commit object based on the provided tree object and parent commits.

  A commit object may have any number of parents. With exactly one parent, it is an
  ordinary commit. Having more than one parent makes the commit a merge between
  several lines of history. Initial (root) commits have no parents.

  Analogous to
  [`git commit-tree`](https://git-scm.com/docs/git-commit-tree).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  ## Options

  `tree`: (`Xgit.ObjectId`, required) ID of tree object

  `parents`: (list of `Xgit.ObjectId`) parent commit object IDs

  `message`: (byte list, required) commit message

  `author`: (`Xgit.PersonIdent`, required) author name, email, timestamp

  `committer`: (`Xgit.PersonIdent`) committer name, email timestamp
  (defaults to `author` if not specified)

  ## Return Value

  `{:ok, object_id}` with the object ID for the commit that was generated.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :invalid_tree}` if the `:tree` option refers to a tree that
  does not exist.

  `{:error, :invalid_parents}` if the `:parents` option is not a list.

  `{:error, :invalid_parent_ids}` if the `:parents` option contains any entries that
  do not reference valid commit objects.

  `{:error, :invalid_message}` if the `:message` option isn't a valid byte string.

  `{:error, :invalid_author}` if the `:author` option isn't a valid `PersonIdent` struct.

  `{:error, :invalid_committer}` if the `:committer` option isn't a valid `PersonIdent` struct.

  Reason codes may also come from `Xgit.Repository.Storage.put_loose_object/2`.
  """
  @spec commit_tree(repository :: Storage.t(),
          tree: ObjectId.t(),
          parents: [ObjectId.t()],
          message: [byte],
          author: PersonIdent.t(),
          committer: PersonIdent.t()
        ) ::
          {:ok, object_id :: ObjectId.t()}
          | {:error, reason :: commit_tree_reason}
  def commit_tree(repository, opts \\ []) when is_pid(repository) do
    with {:repository_valid?, true} <- {:repository_valid?, Storage.valid?(repository)},
         {_tree, _parents, _message, _author, _committer} = verified_args <-
           validate_commit_tree_options(repository, opts),
         commit <- make_commit(verified_args),
         %{id: id} = object <- Commit.to_object(commit),
         :ok <- Storage.put_loose_object(repository, object) do
      cover {:ok, id}
    else
      {:repository_valid?, _} -> cover {:error, :invalid_repository}
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp validate_commit_tree_options(repository, opts) do
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
         {:ok, %Object{id: id} = object} <- Storage.get_object(repository, tree_id),
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
         {:ok, %Object{type: :commit}} <- Storage.get_object(repository, parent_id) do
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
      message: ensure_trailing_newline(message)
    }
  end

  defp ensure_trailing_newline(message) do
    if List.last(message) == 10 do
      message
    else
      message ++ '\n'
    end
  end

  ## --- Working Tree ---

  @typedoc ~S"""
  Reason codes that can be returned by `ls_files_stage_/1`.
  """
  @type ls_files_stage_reason :: :invalid_repository | ParseIndexFile.from_iodevice_reason()

  @doc ~S"""
  Retrieves information about files in the working tree as described by the index file.

  Analogous to
  [`git ls-files --stage`](https://git-scm.com/docs/git-ls-files#Documentation/git-ls-files.txt---stage).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  ## Return Value

  `{:ok, entries}`. `entries` will be a list of `Xgit.DirCache.Entry` structs
  in sorted order.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :bare}` if `repository` doesn't have a working tree.

  `{:error, reason}` if the index file for `repository` isn't valid. (See
  `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1` for possible
  reason codes.)
  """
  @spec ls_files_stage(repository :: Storage.t()) ::
          {:ok, entries :: [DirCacheEntry.t()]}
          | {:error, reason :: ls_files_stage_reason}
  def ls_files_stage(repository) when is_pid(repository) do
    with {:ok, working_tree} <- working_tree_from_opts(repository),
         {:ok, %DirCache{entries: entries} = _dir_cache} <-
           WorkingTree.dir_cache(working_tree) do
      cover {:ok, entries}
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  @typedoc ~S"""
  Cache info tuple `{mode, object_id, path}` to add to the index file.
  """
  @type add_entry :: {mode :: FileMode.t(), object_id :: ObjectId.t(), path :: FilePath.t()}

  @typedoc ~S"""
  Reason codes that can be returned by `update_index_cache_info/2`.
  """
  @type update_index_cache_info_reason ::
          :invalid_repository
          | :invalid_entry
          | :bare
          | Xgit.Repository.WorkingTree.update_dir_cache_reason()

  @doc ~S"""
  Update the index file to reflect new contents.

  Analogous to the `--cacheinfo` form of
  [`git update-index`](https://git-scm.com/docs/git-update-index#Documentation/git-update-index.txt---cacheinfoltmodegtltobjectgtltpathgt).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to which the new entries should be written.

  `add`: a list of tuples of `{mode, object_id, path}` entries to add to the dir cache.
  In the event of collisions with existing entries, the existing entries will
  be replaced with the corresponding new entries.

  `remove`: a list of paths to remove from the dir cache. All versions of the file,
  regardless of stage, will be removed.

  ## Return Value

  `:ok` if successful.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :bare}` if `repository` doesn't have a working tree.

  `{:error, :invalid_entry}` if any tuple passed to `add` or `remove` was invalid.

  `{:error, :reason}` if unable. The relevant reason codes may come from
  `Xgit.Repository.WorkingTree.update_dir_cache/3`.
  """
  @spec update_index_cache_info(
          repository :: Storage.t(),
          add :: [add_entry],
          remove :: [FilePath.t()]
        ) ::
          :ok | {:error, update_index_cache_info_reason()}
  def update_index_cache_info(repository, add, remove \\ [])
      when is_pid(repository) and is_list(add) and is_list(remove) do
    with {:ok, working_tree} <- working_tree_from_opts(repository),
         {:items_to_add, add} when is_list(add) <- {:items_to_add, parse_add_entries(add)},
         {:items_to_remove, remove} when is_list(remove) <-
           {:items_to_remove, parse_remove_entries(remove)} do
      WorkingTree.update_dir_cache(working_tree, add, remove)
    else
      {:items_to_add, _} -> cover {:error, :invalid_entry}
      {:items_to_remove, _} -> cover {:error, :invalid_entry}
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp parse_add_entries(add) do
    if Enum.all?(add, &valid_add?/1) do
      Enum.map(add, &map_add_entry/1)
    else
      cover :invalid
    end
  end

  defp valid_add?({mode, object_id, path})
       when is_file_mode(mode) and is_binary(object_id) and is_list(path),
       do: ObjectId.valid?(object_id) and FilePath.valid?(path)

  defp valid_add?(_), do: cover(false)

  defp map_add_entry({mode, object_id, path}) do
    %DirCacheEntry{
      name: path,
      stage: 0,
      object_id: object_id,
      mode: mode,
      size: 0,
      ctime: 0,
      ctime_ns: 0,
      mtime: 0,
      mtime_ns: 0,
      dev: 0,
      ino: 0,
      uid: 0,
      gid: 0,
      assume_valid?: false,
      extended?: false,
      skip_worktree?: false,
      intent_to_add?: false
    }
  end

  defp parse_remove_entries(remove) do
    if Enum.all?(remove, &valid_remove?/1) do
      Enum.map(remove, &map_remove_entry/1)
    else
      cover :invalid
    end
  end

  defp valid_remove?(name) when is_list(name), do: cover(true)
  defp valid_remove?(_), do: cover(false)

  defp map_remove_entry(name), do: cover({name, :all})

  @typedoc ~S"""
  Reason codes that can be returned by `read_tree/3`.
  """
  @type read_tree_reason ::
          :invalid_repository
          | :bare
          | WorkingTree.read_tree_reason()

  @doc ~S"""
  Read a `tree` object (and its descendants) and populate the index accordingly.

  Does not update files in the working tree itself.

  Analogous to [`git read-tree`](https://git-scm.com/docs/git-read-tree).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  `object_id` is the object ID of the root working tree. The special name `:empty`
  may be used to empty the index.

  ## Options

  `:missing_ok?`: `true` to ignore any objects that are referenced by the tree
  structures that are not present in the object database. Normally this would be an error.

  ## Return Value

  `:ok` if successful.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :bare}` if `repository` doesn't have a working tree.

  Reason codes may also come from the following functions:

  * `Xgit.Repository.Storage.get_object/2`
  * `Xgit.Repository.Storage.WorkingTree.read_tree/3`
  * `Xgit.Repository.Storage.WorkingTree.WriteIndexFile.to_iodevice/2`
  * `Xgit.Tree.from_object/1`

  ## TO DO

  Implement `--prefix` option. https://github.com/elixir-git/xgit/issues/175
  """
  @spec read_tree(repository :: Storage.t(), object_id :: ObjectId.t(), missing_ok?: boolean) ::
          :ok | {:error, reason :: read_tree_reason}
  def read_tree(repository, object_id, opts \\ [])
      when is_pid(repository) and (is_binary(object_id) or object_id == :empty) and is_list(opts) do
    with {:ok, working_tree} <- working_tree_from_opts(repository),
         _missing_ok? <- validate_read_tree_options(opts) do
      if object_id == :empty do
        WorkingTree.reset_dir_cache(working_tree)
      else
        WorkingTree.read_tree(working_tree, object_id, opts)
      end
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp validate_read_tree_options(opts) do
    missing_ok? = Keyword.get(opts, :missing_ok?, false)

    unless is_boolean(missing_ok?) do
      raise ArgumentError,
            "Xgit.Repository.Plumbing.read_tree/3: missing_ok? #{inspect(missing_ok?)} is invalid"
    end

    missing_ok?
  end

  @typedoc ~S"""
  Reason codes that can be returned by `write_tree/2`.
  """
  @type write_tree_reason ::
          :invalid_repository
          | :bare
          | DirCache.to_tree_objects_reason()
          | Storage.put_loose_object_reason()
          | WorkingTree.write_tree_reason()
          | ParseIndexFile.from_iodevice_reason()

  @doc ~S"""
  Translates the current working tree, as reflected in its index file, to one or more
  tree objects.

  The working tree must be in a fully-merged state.

  Analogous to [`git write-tree`](https://git-scm.com/docs/git-write-tree).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  ## Options

  `:missing_ok?`: `true` to ignore any objects that are referenced by the index
  file that are not present in the object database. Normally this would be an error.

  `:prefix`: (`Xgit.FilePath`) if present, returns the `object_id` for the tree at
  the given subdirectory. If not present, writes a tree corresponding to the root.
  (The entire tree is written in either case.)

  ## Return Value

  `{:ok, object_id}` with the object ID for the tree that was generated. (If the exact tree
  specified by the index already existed, it will return that existing tree's ID.)

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  `{:error, :bare}` if `repository` doesn't have a working tree.

  Reason codes may also come from the following functions:

  * `Xgit.DirCache.to_tree_objects/2`
  * `Xgit.Repository.Storage.put_loose_object/2`
  * `Xgit.Repository.Storage.WorkingTree.write_tree/2`
  * `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1`
  """
  @spec write_tree(repository :: Storage.t(), missing_ok?: boolean, prefix: FilePath.t()) ::
          {:ok, object_id :: ObjectId.t()}
          | {:error, reason :: write_tree_reason}
  def write_tree(repository, opts \\ []) when is_pid(repository) do
    with {:ok, working_tree} <- working_tree_from_opts(repository),
         _ <- validate_write_tree_options(opts) do
      cover WorkingTree.write_tree(working_tree, opts)
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp validate_write_tree_options(opts) do
    missing_ok? = Keyword.get(opts, :missing_ok?, false)

    unless is_boolean(missing_ok?) do
      raise ArgumentError,
            "Xgit.Repository.Plumbing.write_tree/2: missing_ok? #{inspect(missing_ok?)} is invalid"
    end

    prefix = Keyword.get(opts, :prefix, [])

    unless prefix == [] or FilePath.valid?(prefix) do
      raise ArgumentError,
            "Xgit.Repository.Plumbing.write_tree/2: prefix #{inspect(prefix)} is invalid (should be a charlist, not a String)"
    end

    {missing_ok?, prefix}
  end

  ## -- References --

  @typedoc ~S"""
  Reason codes that can be returned by `update_ref/4`.
  """
  @type update_ref_reason :: :invalid_repository | Storage.put_ref_reason()

  @doc ~S"""
  Update the object name stored in a ref.

  Analogous to [`git update-ref`](https://git-scm.com/docs/git-update-ref).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) to search for the object.

  `name` is the name of the reference to update. (See `t/Xgit.Ref.name`.)

  `new_value` is the object ID to be written at this reference. (Use `Xgit.ObjectId.zero/0` to delete the reference.)

  ## Options

  `old_target`: If present, a ref with this name must already exist and the `target`
  value must match the object ID provided in this option. (There is a special value `:new`
  which instead requires that the named ref must **not** exist.)

  ## TO DO

  Follow symbolic links, but only if they start with `refs/`.
  (https://github.com/elixir-git/xgit/issues/241)

  ## Return Value

  `:ok` if written successfully.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  Reason codes may also come from the following functions:

  * `Xgit.Repository.Storage.put_ref/3`
  * `Xgit.Repository.Storage.delete_ref/3`
  """
  @spec update_ref(repository :: Storage.t(), name :: Ref.name(), new_value :: ObjectId.t(),
          old_target: ObjectId.t()
        ) :: :ok | {:error, reason :: update_ref_reason}
  def update_ref(repository, name, new_value, opts \\ [])
      when is_pid(repository) and is_binary(name) and is_binary(new_value) and is_list(opts) do
    with {:repository_valid?, true} <- {:repository_valid?, Storage.valid?(repository)},
         repo_opts <- validate_update_ref_opts(opts) do
      if new_value == ObjectId.zero() do
        Storage.delete_ref(repository, name, repo_opts)
      else
        Storage.put_ref(repository, %Ref{name: name, target: new_value}, repo_opts)
      end
    else
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
    end
  end

  defp validate_update_ref_opts(opts) do
    case validate_old_target(Keyword.get(opts, :old_target, nil)) do
      nil -> cover []
      old_target -> cover [{:old_target, old_target}]
    end
  end

  defp validate_old_target(nil) do
    cover nil
  end

  defp validate_old_target(:new) do
    cover :new
  end

  defp validate_old_target(old_target) do
    if ObjectId.valid?(old_target) do
      cover old_target
    else
      raise ArgumentError,
            "Xgit.Repository.Plumbing.update_ref/4: old_target #{inspect(old_target)} is invalid"
    end
  end

  @typedoc ~S"""
  Reason codes that can be returned by `put_symbolic_ref/4`.
  """
  @type put_symbolic_ref_reason :: :invalid_repository | Storage.put_ref_reason()

  @doc ~S"""
  Creates or updates a symbolic ref to point at a specific branch.

  Analogous to the two-argument form of
  [`git symbolic-ref`](https://git-scm.com/docs/git-symbolic-ref).

  ## Parameters

  `repository` is the `Xgit.Repository.Storage` (PID) in which to create the symbolic reference.

  `name` is the name of the symbolic reference to create or update. (See `t/Xgit.Ref.name`.)

  `new_target` is the name of the reference that should be targeted by this symbolic reference.
  This reference need not exist.

  ## Options

  TO DO: Add option to specify ref log message.
  https://github.com/elixir-git/xgit/issues/251

  ## Return Value

  `:ok` if written successfully.

  `{:error, :invalid_repository}` if `repository` doesn't represent a valid
  `Xgit.Repository.Storage` process.

  Reason codes may also come from the following functions:

  * `Xgit.Repository.Storage.put_ref/3`
  """
  @spec put_symbolic_ref(
          repository :: Storage.t(),
          name :: Ref.name(),
          new_target :: Ref.name(),
          opts :: Keyword.t()
        ) :: :ok | {:error, reason :: put_symbolic_ref_reason}
  def put_symbolic_ref(repository, name, new_target, opts \\ [])
      when is_pid(repository) and is_binary(name) and is_binary(new_target) and is_list(opts) do
    if Storage.valid?(repository) do
      Storage.put_ref(repository, %Ref{name: name, target: "ref: #{new_target}"},
        follow_link?: false
      )
    else
      cover {:error, :invalid_repository}
    end
  end

  ## --- Options ---

  # Parse working tree and repository from arguments and options.

  defp working_tree_from_opts(repository, opts \\ []) when is_pid(repository) and is_list(opts) do
    with {:repository_valid?, true} <- {:repository_valid?, Storage.valid?(repository)},
         {:working_tree, working_tree} when is_pid(working_tree) <-
           {:working_tree, working_tree_from_repo_or_opts(repository, opts)} do
      cover {:ok, working_tree}
    else
      {:repository_valid?, false} -> cover {:error, :invalid_repository}
      {:working_tree, nil} -> cover {:error, :bare}
    end
  end

  defp working_tree_from_repo_or_opts(repository, _opts) do
    # TO DO: Allow working tree to be specified via options.
    # https://github.com/elixir-git/xgit/issues/133
    # (NOTE: Should follow through to ensure all relevant plumbing
    # modules have that option documented when implemented.)
    # For now, only recognize default working tree.

    Storage.default_working_tree(repository)
  end
end
