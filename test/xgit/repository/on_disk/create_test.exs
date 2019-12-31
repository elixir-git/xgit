defmodule Xgit.Repository.OnDisk.CreateTest do
  use ExUnit.Case, async: true

  alias Xgit.Repository.OnDisk
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  describe "create/1" do
    test "happy path matches command-line git" do
      %{xgit_path: ref} = OnDiskRepoTestCase.repo!()
      %{xgit_path: xgit_root} = OnDiskRepoTestCase.repo!()

      xgit = Path.join(xgit_root, "repo")

      assert :ok = OnDisk.create(xgit)
      assert_folders_are_equal(ref, xgit)
    end

    test "error: no work_dir" do
      assert_raise FunctionClauseError, fn ->
        OnDisk.create(nil)
      end
    end

    test "error: work dir exists already" do
      %{xgit_path: xgit_root} = OnDiskRepoTestCase.repo!()
      xgit = Path.join(xgit_root, "repo")

      File.mkdir_p!(xgit)
      assert {:error, :work_dir_must_not_exist} = OnDisk.create(xgit)
    end
  end
end
