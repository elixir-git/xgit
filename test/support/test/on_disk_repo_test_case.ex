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
  """
  @spec repo! :: %{tmp_dir: Path.t(), xgit_path: Path.t(), xgit_repo: Repository.t()}
  def repo!, do: git_init_repo(TempDirTestCase.tmp_dir!())

  @doc ~S"""
  Returns a context with an on-disk repository set up.

  Unlike `repo!/0`, this takes a hard-wired path and uses that instead.
  Ensures that this directory is created and empty.

  Use this when debugging tests that fail so you can inspect contents
  after the test run.
  """
  @spec repo!(dir :: Path.t()) :: %{
          tmp_dir: Path.t(),
          xgit_path: Path.t(),
          xgit_repo: Repository.t()
        }
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
