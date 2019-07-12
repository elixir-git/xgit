defmodule Xgit.Repository.OnDisk.InitTest do
  use ExUnit.Case

  alias Xgit.Repository.OnDisk

  import FolderDiff

  setup do
    Temp.track!()
    tmp = Temp.mkdir!()
    ref = Path.join(tmp, "ref")
    xgit = Path.join(tmp, "xgit")

    {:ok, ref: ref, xgit: xgit}
  end

  describe "init/1" do
    test "happy path matches command-line git", %{ref: ref, xgit: xgit} do
      File.mkdir_p!(ref)
      {_, 0} = System.cmd("git", ["init", "."], cd: ref)

      assert :ok = OnDisk.init(work_dir: xgit)

      assert_folders_are_equal(ref, xgit)
    end

    test "error: no work_dir" do
      assert_raise ArgumentError, fn ->
        OnDisk.init([])
      end
    end

    test "error: work dir exists already", %{xgit: xgit} do
      File.mkdir_p!(xgit)

      assert_raise ArgumentError, fn ->
        OnDisk.init(work_dir: xgit)
      end
    end
  end
end
