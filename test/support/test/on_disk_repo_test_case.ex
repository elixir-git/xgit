defmodule Xgit.Test.OnDiskRepoTestCase do
  @moduledoc ~S"""
  (Testing only) Test case that sets up a temporary directory with an on-disk repositort.
  """
  use ExUnit.CaseTemplate

  alias Xgit.Repository
  alias Xgit.Repository.OnDisk
  alias Xgit.Test.TempDirTestCase

  setup do
    {:ok, repo!()}
  end

  @doc ~S"""
  Returns a context with an on-disk repository set up.
  """
  @spec repo!() :: %{tmp_dir: Path.t(), xgit_repo: Repository.t()}
  def repo! do
    %{tmp_dir: xgit_path} = context = TempDirTestCase.tmp_dir!()

    {_output, 0} = System.cmd("git", ["init"], cd: xgit_path)
    {:ok, xgit_repo} = OnDisk.start_link(work_dir: xgit_path)

    Map.merge(context, %{xgit_path: xgit_path, xgit_repo: xgit_repo})
  end
end
