defmodule Xgit.Repository.OnDisk.CreateTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Repository.OnDisk

  import FolderDiff

  describe "create/1" do
    test "happy path matches command-line git", %{ref: ref, xgit: xgit} do
      assert :ok = OnDisk.create(xgit)
      assert_folders_are_equal(ref, xgit)
    end

    test "error: no work_dir" do
      assert_raise FunctionClauseError, fn ->
        OnDisk.create(nil)
      end
    end

    test "error: work dir exists already", %{xgit: xgit} do
      File.mkdir_p!(xgit)
      assert {:error, :work_dir_must_not_exist} = OnDisk.create(xgit)
    end
  end
end
