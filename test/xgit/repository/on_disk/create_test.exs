defmodule Xgit.Repository.OnDisk.CreateTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Repository.OnDisk

  import FolderDiff

  describe "create/1" do
    test "happy path matches command-line git", %{ref: ref, xgit: xgit} do
      assert :ok = OnDisk.create(work_dir: xgit)
      assert_folders_are_equal(ref, xgit)
    end

    test "error: no work_dir" do
      assert_raise ArgumentError, fn ->
        OnDisk.create([])
      end
    end

    test "error: work dir exists already", %{xgit: xgit} do
      File.mkdir_p!(xgit)

      assert_raise ArgumentError, fn ->
        OnDisk.create(work_dir: xgit)
      end
    end
  end
end
