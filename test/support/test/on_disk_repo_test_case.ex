defmodule Xgit.Test.OnDiskRepoTestCase do
  @moduledoc ~S"""
  (Testing only) Test case that sets up a temporary directory with an on-disk repositort.
  """
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
  """
  @spec repo!(path :: Path.t() | nil) :: %{
          tmp_dir: Path.t(),
          xgit_path: Path.t(),
          xgit_repo: Repository.t()
        }
  def repo!(path \\ nil)

  def repo!(nil), do: git_init_repo(TempDirTestCase.tmp_dir!())

  def repo!(dir) when is_binary(dir) do
    File.rm_rf!(dir)
    File.mkdir!(dir)
    git_init_repo(%{tmp_dir: dir})
  end

  defp git_init_repo(%{tmp_dir: xgit_path} = context) do
    {_output, 0} = System.cmd("git", ["init"], cd: xgit_path)
    {:ok, xgit_repo} = OnDisk.start_link(work_dir: xgit_path)

    Map.merge(context, %{xgit_path: xgit_path, xgit_repo: xgit_repo})
  end
end
