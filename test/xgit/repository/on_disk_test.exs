defmodule Xgit.Repository.OnDiskTest do
  use ExUnit.Case, async: true

  alias Xgit.Repository
  alias Xgit.Repository.OnDisk
  alias Xgit.Repository.Storage
  alias Xgit.Repository.WorkingTree
  alias Xgit.Test.OnDiskRepoTestCase
  alias Xgit.Test.TempDirTestCase

  import ExUnit.CaptureLog

  describe "start_link/1" do
    test "happy path: starts and is valid and has a working directory attached" do
      %{tmp_dir: xgit_root} = TempDirTestCase.tmp_dir!()

      xgit = Path.join(xgit_root, "tmp")

      assert :ok = OnDisk.create(xgit)
      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert is_pid(repo)
      assert Repository.valid?(repo)
      assert Storage.valid?(repo)
      Storage.assert_valid(repo)

      assert working_tree = Storage.default_working_tree(repo)
      assert is_pid(working_tree)
      assert WorkingTree.valid?(working_tree)
    end

    test "error: can't launch because bad config file" do
      %{tmp_dir: xgit_root} = TempDirTestCase.tmp_dir!()

      xgit = Path.join(xgit_root, "tmp")

      assert :ok = OnDisk.create(xgit)

      config_path = Path.join([xgit_root, "tmp", ".git", "config"])
      File.write!(config_path, "[bogus] config var name with spaces = bogus")

      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert is_pid(repo)
      assert Repository.valid?(repo)
      assert Storage.valid?(repo)
      Storage.assert_valid(repo)

      assert working_tree = Storage.default_working_tree(repo)
      assert is_pid(working_tree)
      assert WorkingTree.valid?(working_tree)
    end

    test "handles unknown message" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert capture_log(fn ->
               assert {:error, :unknown_message} = GenServer.call(repo, :random_unknown_message)
             end) =~ "Repository received unrecognized call :random_unknown_message"
    end

    test "error: missing work_dir" do
      Process.flag(:trap_exit, true)
      assert {:error, :missing_arguments} = OnDisk.start_link([])
    end

    test "error: work_dir doesn't exist" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

      Process.flag(:trap_exit, true)

      assert {:error, :work_dir_doesnt_exist} =
               OnDisk.start_link(work_dir: Path.join(xgit, "random"))
    end

    test "error: git_dir doesn't exist" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

      Process.flag(:trap_exit, true)

      temp_dir = Path.join(xgit, "blah")
      File.mkdir_p!(temp_dir)

      assert {:error, :git_dir_doesnt_exist} = OnDisk.start_link(work_dir: temp_dir)
    end
  end
end
