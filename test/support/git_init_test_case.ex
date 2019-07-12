defmodule Xgit.GitInitTestCase do
  @moduledoc false
  # Creates a temporary directory containing an
  # initialized, but otherwise empty git repo and
  # adjacent space for an Xgit-created git repo.

  use ExUnit.CaseTemplate

  setup do
    Temp.track!()
    tmp = Temp.mkdir!()
    ref = Path.join(tmp, "ref")
    xgit = Path.join(tmp, "xgit")

    git_init_and_standardize(ref)

    {:ok, ref: ref, xgit: xgit}
  end

  defp git_init_and_standardize(git_dir) do
    git_dir
    |> git_init()
    |> remove_sample_hooks()
    |> rewrite_config()
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

  defp rewrite_config(git_dir) do
    git_dir
    |> Path.join(".git/config")
    |> File.write!(~s"""
    [core]
    \trepositoryformatversion = 0
    \tfilemode = true
    \tbare = false
    \tlogallrefupdates = true
    """)

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
end
