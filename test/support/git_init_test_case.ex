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
    File.mkdir_p!(git_dir)
    {_, 0} = System.cmd("git", ["init", "."], cd: git_dir)

    remove_sample_hooks(git_dir)
    rewrite_config(git_dir)
  end

  defp remove_sample_hooks(git_dir) do
    hooks_dir = Path.join(git_dir, ".git/hooks")

    hooks_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".sample"))
    |> Enum.each(&File.rm!(Path.join(hooks_dir, &1)))
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
  end
end
