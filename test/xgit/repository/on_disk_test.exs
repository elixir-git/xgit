defmodule Xgit.Repository.OnDiskTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Repository
  alias Xgit.Repository.OnDisk

  import ExUnit.CaptureLog

  describe "start_link/1" do
    test "happy path: starts and is valid", %{xgit: xgit} do
      assert :ok = OnDisk.create(work_dir: xgit)

      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)
      assert is_pid(repo)

      assert Repository.valid?(repo)
    end

    test "handles unknown message", %{xgit: xgit} do
      assert :ok = OnDisk.create(work_dir: xgit)
      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert capture_log(fn ->
               assert {:error, :unknown_message} = GenServer.call(repo, :random_unknown_message)
             end) =~ "Repository received unrecognized call :random_unknown_message"
    end

    test "error: missing work_dir" do
      Process.flag(:trap_exit, true)
      assert {:error, :missing_arguments} = OnDisk.start_link([])
    end
  end
end
