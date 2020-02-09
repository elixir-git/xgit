defmodule Xgit.Test.OnDiskRepoTestCase do
  @moduledoc false
  # (Testing only) Test case that sets up a temporary directory with an on-disk repository.
  use ExUnit.CaseTemplate

  alias Xgit.Repository.OnDisk
  alias Xgit.Test.TempDirTestCase

  setup do
    {:ok, repo!()}
  end

  @doc ~S"""
  Returns a context with an on-disk repository set up.

  Can optionally take a hard-wired path to use instead of the default
  temporary directory. Use that when you need to debug a test that is
  failing and you want to inspect the repo after the test completes.

  ## Options

  * `config_file_content:` (`String` | nil) optional override for `.git/config`
    file (a string means use this content; `nil` means do not create the file)
  """
  @spec repo!(path :: Path.t() | nil, config_file_content: String.t()) :: %{
          tmp_dir: Path.t(),
          xgit_path: Path.t(),
          xgit_repo: Storage.t()
        }
  def repo!(path \\ nil, opts \\ [])

  def repo!(nil, opts) when is_list(opts), do: git_init_repo(TempDirTestCase.tmp_dir!(), opts)

  def repo!(dir, opts) when is_binary(dir) and is_list(opts) do
    File.rm_rf!(dir)
    File.mkdir!(dir)
    git_init_repo(%{tmp_dir: dir}, opts)
  end

  defp git_init_repo(%{tmp_dir: xgit_path} = context, opts) do
    git_init_and_standardize(xgit_path, opts)

    {:ok, xgit_repo} = OnDisk.start_link(work_dir: xgit_path)

    Map.merge(context, %{xgit_path: xgit_path, xgit_repo: xgit_repo})
  end

  @default_config_file_content ~s"""
  [core]
  \trepositoryformatversion = 0
  \tfilemode = true
  \tbare = false
  \tlogallrefupdates = true
  """
  defp git_init_and_standardize(git_dir, opts) do
    git_dir
    |> git_init()
    |> remove_sample_hooks()
    |> rewrite_config(Keyword.get(opts, :config_file_content, @default_config_file_content))
    |> rewrite_info_exclude()
  end

  defp git_init(git_dir) do
    {_, 0} = System.cmd("git", ["init", git_dir])
    git_dir
  end

  defp remove_sample_hooks(git_dir) do
    hooks_dir = Path.join(git_dir, ".git/hooks")

    hooks_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".sample"))
    |> Enum.each(&File.rm!(Path.join(hooks_dir, &1)))

    git_dir
  end

  defp rewrite_config(git_dir, config_file_content) when is_binary(config_file_content) do
    git_dir
    |> Path.join(".git/config")
    |> File.write!(config_file_content)

    git_dir
  end

  defp rewrite_config(git_dir, nil) do
    git_dir
    |> Path.join(".git/config")
    |> File.rm()

    git_dir
  end

  defp rewrite_info_exclude(git_dir) do
    git_dir
    |> Path.join(".git/info/exclude")
    |> File.write!(~s"""
    # git ls-files --others --exclude-from=.git/info/exclude
    # Lines that start with '#' are comments.
    # For a project mostly in C, the following would be a good set of
    # exclude patterns (uncomment them if you want to use them):
    # *.[oa]
    # *~
    .DS_Store
    """)

    git_dir
  end

  @doc ~S"""
  Returns a pre-configured environment for a known author/committer ID and timestamp.
  """
  @spec sample_commit_env() :: [{String.t(), String.t()}]
  def sample_commit_env do
    [
      {"GIT_AUTHOR_DATE", "1142878449 +0230"},
      {"GIT_COMMITTER_DATE", "1142878449 +0230"},
      {"GIT_AUTHOR_EMAIL", "author@example.com"},
      {"GIT_COMMITTER_EMAIL", "author@example.com"},
      {"GIT_AUTHOR_NAME", "A. U. Thor"},
      {"GIT_COMMITTER_NAME", "A. U. Thor"}
    ]
  end

  @doc ~S"""
  Returns a context with an on-disk repository set up.

  This repository has a tree object with one file in it.

  Can optionally take a hard-wired path to use instead of the default
  temporary directory. Use that when you need to debug a test that is
  failing and you want to inspect the repo after the test completes.
  """
  @spec setup_with_valid_tree!(path :: Path.t() | nil) :: %{
          tmp_dir: Path.t(),
          xgit_path: Path.t(),
          xgit_repo: Storage.t(),
          tree_id: binary()
        }
  def setup_with_valid_tree!(path \\ nil) do
    %{xgit_path: xgit_path} = context = repo!(path)

    test_content_path = Temp.path!()
    File.write!(test_content_path, "test content\n")

    {object_id_str, 0} =
      System.cmd(
        "git",
        [
          "hash-object",
          "-w",
          "--",
          test_content_path
        ],
        cd: xgit_path
      )

    object_id = String.trim(object_id_str)

    {_output, 0} =
      System.cmd(
        "git",
        [
          "update-index",
          "--add",
          "--cacheinfo",
          "100644",
          object_id,
          "test"
        ],
        cd: xgit_path
      )

    {tree_id_str, 0} =
      System.cmd(
        "git",
        [
          "write-tree"
        ],
        cd: xgit_path
      )

    tree_id = String.trim(tree_id_str)

    Map.put(context, :tree_id, tree_id)
  end

  @doc ~S"""
  Returns a context with an on-disk repository set up.

  This repository has a tree object with one file in it and an
  empty commit.

  Can optionally take a hard-wired path to use instead of the default
  temporary directory. Use that when you need to debug a test that is
  failing and you want to inspect the repo after the test completes.
  """
  @spec setup_with_valid_parent_commit!(path :: Path.t() | nil) :: %{
          tmp_dir: Path.t(),
          xgit_path: Path.t(),
          xgit_repo: Storage.t(),
          tree_id: String.t(),
          parent_id: String.t()
        }
  def setup_with_valid_parent_commit!(path \\ nil) do
    %{xgit_path: xgit_path} = context = setup_with_valid_tree!(path)

    {empty_tree_id_str, 0} =
      System.cmd(
        "git",
        [
          "write-tree"
        ],
        cd: xgit_path
      )

    empty_tree_id = String.trim(empty_tree_id_str)

    {parent_id_str, 0} =
      System.cmd(
        "git",
        [
          "commit-tree",
          "-m",
          "empty",
          empty_tree_id
        ],
        cd: xgit_path,
        env: sample_commit_env()
      )

    parent_id = String.trim(parent_id_str)

    Map.put(context, :parent_id, parent_id)
  end
end
