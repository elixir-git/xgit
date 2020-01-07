defmodule Xgit.Repository.OnDisk do
  @moduledoc ~S"""
  Implementation of `Xgit.Repository.Storage` that stores content on the
  local file system.

  _IMPORTANT NOTE:_ This is intended as a reference implementation largely
  for testing purposes and may not necessarily handle all of the edge cases that
  the traditional `git` command-line interface will handle.

  That said, it does intentionally use the same `.git` folder format as command-line
  `git` so that results may be compared for similar operations.
  """
  use Xgit.Repository.Storage

  import Xgit.Util.ForceCoverage

  alias Xgit.ContentSource
  alias Xgit.Object
  alias Xgit.Ref
  alias Xgit.Repository.WorkingTree
  alias Xgit.Util.FileUtils
  alias Xgit.Util.ParseDecimal
  alias Xgit.Util.UnzipStream

  @doc ~S"""
  Start an on-disk git repository.

  Use the functions in `Xgit.Repository.Storage` to interact with this repository process.

  An `Xgit.Repository.WorkingTree` will be automatically created and attached
  to this repository.

  ## Options

  * `:work_dir` (required): Top-level working directory. A `.git` directory should
    exist at this path. Use `create/1` to create an empty on-disk repository if
    necessary.

  Any other options are passed through to `GenServer.start_link/3`.

  ## Return Value

  See `GenServer.start_link/3`.

  `{:error, :work_dir_invalid}` if `work_dir` is missing or not a String.
  """
  @spec start_link(work_dir: Path.t()) :: GenServer.on_start()
  def start_link(opts) do
    with {:ok, work_dir} <- get_work_dir_opt(opts),
         {:ok, repo} <- Storage.start_link(__MODULE__, work_dir, opts),
         {:ok, working_tree} <- WorkingTree.start_link(repo, work_dir),
         :ok <- Storage.set_default_working_tree({:xgit_repo, repo}, working_tree) do
      cover {:ok, repo}
    else
      err -> err
    end
  end

  defp get_work_dir_opt(opts) do
    with {:has_opt?, true} <- {:has_opt?, Keyword.has_key?(opts, :work_dir)},
         work_dir <- Keyword.get(opts, :work_dir),
         true <- is_binary(work_dir) do
      {:ok, work_dir}
    else
      {:has_opt?, _} -> {:error, :missing_arguments}
      _ -> {:error, :work_dir_invalid}
    end
  end

  @impl true
  def init(work_dir) when is_binary(work_dir) do
    # TO DO: Be smarter about bare repos and non-standard git_dir locations.
    # https://github.com/elixir-git/xgit/issues/44

    with {:work_dir, true} <- {:work_dir, File.dir?(work_dir)},
         git_dir <- Path.join(work_dir, ".git"),
         {:git_dir, true} <- {:git_dir, File.dir?(git_dir)} do
      cover {:ok, %{work_dir: work_dir, git_dir: git_dir}}
    else
      {:work_dir, _} -> cover {:stop, :work_dir_doesnt_exist}
      {:git_dir, _} -> cover {:stop, :git_dir_doesnt_exist}
    end
  end

  @doc ~S"""
  Creates a new, empty git repository on the local file system.

  Analogous to [`git init`](https://git-scm.com/docs/git-init).

  _NOTE:_ We use the name `create` here so as to avoid a naming conflict with
  `c:GenServer.init/1`.

  ## Parameters

  `work_dir` (String) is the top-level working directory. A `.git` directory is
  created inside this directory.

  ## Return Value

  `:ok` if created successfully.

  `{:error, :work_dir_must_not_exist}` if `work_dir` already exists.
  """
  @spec create(work_dir :: Path.t()) :: :ok | {:error, :work_dir_must_not_exist}
  def create(work_dir) when is_binary(work_dir) do
    work_dir
    |> assert_not_exists()
    |> create_empty_repo()
  end

  defp assert_not_exists(path) do
    if File.exists?(path) do
      cover {:error, :work_dir_must_not_exist}
    else
      cover {:ok, path}
    end
  end

  defp create_empty_repo({:error, reason}), do: cover({:error, reason})

  # Exception to the usual policy about using `cover` macro:
  # Most of these error cases are about I/O errors that are difficult
  # to simulate (can create parent repo dir, but then can't create
  # a child thereof, etc.). This code is un-complicated, so we
  # choose to leave it silently uncovered.

  defp create_empty_repo({:ok, path}) do
    with :ok <- File.mkdir_p(path),
         :ok <- create_git_dir(Path.join(path, ".git")) do
      cover :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_git_dir(git_dir) do
    with :ok <- create_branches_dir(git_dir),
         :ok <- create_config(git_dir),
         :ok <- create_description(git_dir),
         :ok <- create_head(git_dir),
         :ok <- create_hooks_dir(git_dir),
         :ok <- create_info_dir(git_dir),
         :ok <- create_objects_dir(git_dir),
         :ok <- create_refs_dir(git_dir) do
      cover :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_branches_dir(git_dir) do
    git_dir
    |> Path.join("branches")
    |> File.mkdir_p()
  end

  defp create_config(git_dir) do
    git_dir
    |> Path.join("config")
    |> File.write(~s"""
    [core]
    \trepositoryformatversion = 0
    \tfilemode = true
    \tbare = false
    \tlogallrefupdates = true
    """)
  end

  defp create_description(git_dir) do
    git_dir
    |> Path.join("description")
    |> File.write("Unnamed repository; edit this file 'description' to name the repository.\n")
  end

  defp create_head(git_dir) do
    git_dir
    |> Path.join("HEAD")
    |> File.write("ref: refs/heads/master\n")
  end

  defp create_hooks_dir(git_dir) do
    git_dir
    |> Path.join("hooks")
    |> File.mkdir_p()

    # NOTE: Intentionally not including the sample files.
  end

  defp create_info_dir(git_dir) do
    with info_dir <- Path.join(git_dir, "info"),
         :ok <- File.mkdir_p(info_dir) do
      info_dir
      |> Path.join("exclude")
      |> File.write!(~S"""
      # git ls-files --others --exclude-from=.git/info/exclude
      # Lines that start with '#' are comments.
      # For a project mostly in C, the following would be a good set of
      # exclude patterns (uncomment them if you want to use them):
      # *.[oa]
      # *~
      .DS_Store
      """)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_objects_dir(git_dir) do
    with :ok <- File.mkdir_p(Path.join(git_dir, "objects/info")),
         :ok <- File.mkdir_p(Path.join(git_dir, "objects/pack")) do
      cover :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_refs_dir(git_dir) do
    refs_dir = Path.join(git_dir, "refs")

    with :ok <- File.mkdir_p(refs_dir),
         :ok <- File.mkdir_p(Path.join(refs_dir, "heads")),
         :ok <- File.mkdir_p(Path.join(refs_dir, "tags")) do
      cover :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_has_all_object_ids?(%{git_dir: git_dir} = state, object_ids) do
    has_all_object_ids? =
      Enum.all?(object_ids, fn object_id -> has_object_id?(git_dir, object_id) end)

    cover {:ok, has_all_object_ids?, state}
  end

  defp has_object_id?(git_dir, object_id) do
    loose_object_path =
      Path.join([
        git_dir,
        "objects",
        String.slice(object_id, 0, 2),
        String.slice(object_id, 2, 38)
      ])

    File.regular?(loose_object_path)
  end

  defmodule LooseObjectContentSource do
    @moduledoc false
    # Implements `Xgit.ContentSource` to read content from a loose object.

    import Xgit.Util.ForceCoverage

    @type t :: %__MODULE__{path: Path.t(), size: non_neg_integer}

    @enforce_keys [:path, :size]
    defstruct [:path, :size]

    defimpl Xgit.ContentSource do
      alias Xgit.Repository.OnDisk.LooseObjectContentSource, as: LCS
      @impl true
      def length(%LCS{size: size}), do: cover(size)

      @impl true
      def stream(%LCS{path: path}) do
        path
        |> File.stream!([:binary])
        |> UnzipStream.unzip()
        |> Stream.drop_while(&(&1 != 0))
        |> Stream.drop(1)
      end
    end
  end

  @impl true
  def handle_get_object(state, object_id) do
    case get_object_imp(state, object_id) do
      %Object{} = object -> {:ok, object, state}
      {:error, :not_found} -> {:error, :not_found, state}
      {:error, :invalid_object} -> {:error, :invalid_object, state}
    end
  end

  defp get_object_imp(%{git_dir: git_dir} = _state, object_id) do
    # Currently only checks for loose objects.
    # TO DO: Look for object in packs.
    # https://github.com/elixir-git/xgit/issues/52

    find_loose_object(git_dir, object_id)
  end

  defp find_loose_object(git_dir, object_id) do
    loose_object_path =
      Path.join([
        git_dir,
        "objects",
        String.slice(object_id, 0, 2),
        String.slice(object_id, 2, 38)
      ])

    with {:exists?, true} <- {:exists?, File.regular?(loose_object_path)},
         {:header, type, length} <- read_loose_object_prefix(loose_object_path) do
      loose_file_to_object(type, length, object_id, loose_object_path)
    else
      {:exists?, false} -> cover {:error, :not_found}
      :invalid_header -> cover {:error, :invalid_object}
    end
  end

  defp read_loose_object_prefix(path) do
    path
    |> File.stream!([:binary], 1000)
    |> UnzipStream.unzip()
    |> Stream.take(100)
    |> Stream.take_while(&(&1 != 0))
    |> Enum.to_list()
    |> Enum.split_while(&(&1 != ?\s))
    |> parse_prefix_and_length()
  rescue
    ErlangError -> cover :invalid_header
  end

  @known_types ['blob', 'tag', 'tree', 'commit']
  @type_to_atom %{'blob' => :blob, 'tag' => :tag, 'tree' => :tree, 'commit' => :commit}

  defp parse_prefix_and_length({type, length}) when type in @known_types,
    do: parse_length(@type_to_atom[type], length)

  defp parse_prefix_and_length(_), do: cover(:invalid_header)

  defp parse_length(_type, ' '), do: cover(:invalid_header)

  defp parse_length(type, [?\s | length]) do
    case ParseDecimal.from_decimal_charlist(length) do
      {length, []} when is_integer(length) and length >= 0 -> {:header, type, length}
      _ -> cover :invalid_header
    end
  end

  defp parse_length(_type, _length), do: cover(:invalid_header)

  defp loose_file_to_object(type, length, object_id, path)
       when is_atom(type) and is_integer(length) do
    %Object{
      type: type,
      size: length,
      id: object_id,
      content: %__MODULE__.LooseObjectContentSource{size: length, path: path}
    }
  end

  @impl true
  def handle_put_loose_object(%{git_dir: git_dir} = state, %Object{id: id} = object) do
    object_dir = Path.join([git_dir, "objects", String.slice(id, 0, 2)])
    path = Path.join(object_dir, String.slice(id, 2, 38))

    with {:mkdir, :ok} <-
           {:mkdir, File.mkdir_p(object_dir)},
         {:file, {:ok, :ok}} <-
           {:file,
            File.open(path, [:write, :binary, :exclusive], fn file_pid ->
              deflate_and_write(file_pid, object)
            end)} do
      cover {:ok, state}
    else
      {:mkdir, _} ->
        {:error, :cant_create_file, state}

      {:file, {:error, :eexist}} ->
        {:error, :object_exists, state}
    end
  end

  defp deflate_and_write(file, %Object{type: type, size: size, content: content}) do
    z = :zlib.open()
    :ok = :zlib.deflateInit(z, 1)

    deflate_and_write_bytes(file, z, '#{type} #{size}')
    deflate_and_write_bytes(file, z, [0])

    if is_list(content) do
      deflate_and_write_bytes(file, z, content, :finish)
    else
      deflate_content(file, z, content)
      deflate_and_write_bytes(file, z, [], :finish)
    end

    :zlib.deflateEnd(z)
  end

  defp deflate_content(file, z, content) do
    content
    |> ContentSource.stream()
    |> Stream.each(fn chunk ->
      deflate_and_write_bytes(file, z, [chunk])
    end)
    |> Stream.run()
  end

  defp deflate_and_write_bytes(file, z, bytes, flush \\ :none),
    do: IO.binwrite(file, :zlib.deflate(z, bytes, flush))

  @impl true
  def handle_list_refs(%{git_dir: git_dir} = state) do
    refs_dir = Path.join(git_dir, "refs")

    # TO DO: Add support for packed refs.
    # https://github.com/elixir-git/xgit/issues/223

    {:ok,
     refs_dir
     |> FileUtils.recursive_files!()
     |> Task.async_stream(fn path -> ref_path_to_ref(git_dir, path) end)
     |> Enum.map(&drop_ref_ok_tuple/1)
     |> Enum.filter(& &1)
     |> Enum.sort(), state}
  end

  defp ref_path_to_ref(git_dir, path),
    do: File.open!(path, &read_ref_imp(String.replace_prefix(path, "#{git_dir}/", ""), &1))

  defp drop_ref_ok_tuple({:ok, %Ref{} = value}), do: value
  defp drop_ref_ok_tuple(_), do: nil

  @impl true
  def handle_put_ref(%{git_dir: git_dir} = state, %Ref{name: name, target: target} = ref, opts) do
    with :ok <- verify_target(state, target),
         {:deref, new_name} <-
           {:deref, deref_sym_link(git_dir, name, Keyword.get(opts, :follow_link?, true))},
         ref <- %{ref | name: new_name},
         {:old_target_matches?, true} <-
           {:old_target_matches?,
            old_target_matches?(git_dir, new_name, Keyword.get(opts, :old_target))},
         :ok <- put_ref_imp(git_dir, ref) do
      # TO DO: Update ref log if so requested. https://github.com/elixir-git/xgit/issues/224
      cover {:ok, state}
    else
      {:error, reason} -> cover {:error, reason, state}
      {:old_target_matches?, _} -> cover {:error, :old_target_not_matched, state}
    end
  end

  defp verify_target(_state, "ref: " <> _), do: cover(:ok)

  defp verify_target(state, target) do
    object = get_object_imp(state, target)

    if object == {:error, :not_found} do
      cover {:error, :target_not_found}
    else
      cover :ok
    end
  end

  defp deref_sym_link(git_dir, ref_name, true = _follow_link?) do
    case get_ref_imp(git_dir, ref_name, false) do
      {:ok, %Ref{target: "ref: " <> link_target}} when link_target != ref_name ->
        deref_sym_link(git_dir, link_target, true)

      _ ->
        ref_name
    end
  end

  defp deref_sym_link(_git_dir, ref_name, _follow_link?), do: cover(ref_name)

  defp old_target_matches?(_git_dir, _name, nil), do: cover(true)

  defp old_target_matches?(git_dir, name, :new) do
    case get_ref_imp(git_dir, name, false) do
      {:ok, _ref} -> cover false
      _ -> cover true
    end
  end

  defp old_target_matches?(git_dir, name, old_target) do
    case get_ref_imp(git_dir, name, false) do
      {:ok, %Ref{target: ^old_target}} -> cover true
      _ -> false
    end
  end

  defp put_ref_imp(git_dir, %Ref{name: name, target: target} = _ref) do
    ref_path = Path.join(git_dir, name)
    ref_dir = Path.dirname(ref_path)

    mkdir_result = File.mkdir_p(ref_dir)

    if mkdir_result == :ok do
      File.write(ref_path, "#{target}\n")
    else
      cover mkdir_result
    end
  end

  @impl true
  def handle_delete_ref(%{git_dir: git_dir} = state, name, opts) do
    with {:old_target_matches?, true} <-
           {:old_target_matches?,
            old_target_matches?(git_dir, name, Keyword.get(opts, :old_target))},
         :ok <- delete_ref_imp(git_dir, name) do
      # TO DO: Update ref log if so requested. https://github.com/elixir-git/xgit/issues/224
      cover {:ok, state}
    else
      {:old_target_matches?, _} -> cover {:error, :old_target_not_matched, state}
      {:error, :enoent} -> cover {:ok, state}
      {:error, _posix} -> cover {:error, :cant_delete_file, state}
    end
  end

  defp delete_ref_imp(git_dir, name) do
    ref_path = Path.join(git_dir, name)
    File.rm(ref_path)
  end

  @impl true
  def handle_get_ref(%{git_dir: git_dir} = state, name, opts) do
    case get_ref_imp(git_dir, name, Keyword.get(opts, :follow_link?, true)) do
      {:ok, %Ref{name: ^name} = ref} ->
        cover {:ok, ref, state}

      {:ok, %Ref{name: link_target} = ref} ->
        cover {:ok, %{ref | link_target: link_target, name: name}, state}

      {:error, reason} ->
        cover {:error, reason, state}
    end
  end

  defp get_ref_imp(git_dir, name, true = _follow_link?) do
    case get_ref_imp(git_dir, name, false) do
      {:ok, %Ref{target: "ref: " <> link_target}} when link_target != name ->
        get_ref_imp(git_dir, link_target, true)

      x ->
        x
    end
  end

  defp get_ref_imp(git_dir, name, _follow_link?) do
    ref_path = Path.join(git_dir, name)

    case File.open(ref_path, [:read], &read_ref_imp(name, &1)) do
      {:ok, %Ref{} = ref} -> cover {:ok, ref}
      {:ok, reason} when is_atom(reason) -> cover {:error, reason}
      {:error, :enoent} -> cover {:error, :not_found}
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp read_ref_imp(name, iodevice) do
    with target when is_binary(target) <-
           IO.read(iodevice, 1024),
         ref <- %Ref{name: name, target: String.trim(target)},
         {:valid_ref?, true} <- {:valid_ref?, Ref.valid?(ref)} do
      ref
    else
      {:valid_ref?, false} -> cover :invalid_ref
      reason when is_atom(reason) -> cover reason
    end
  end
end
