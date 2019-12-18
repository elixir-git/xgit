defmodule Xgit.Repository.Plumbing.DeleteSymbolicRefTest do
  use ExUnit.Case, async: true

  alias Xgit.Repository.Plumbing
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  describe "delete_symbolic_ref/2" do
    test "happy path: target ref does not exist" do
      %{xgit_path: path, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert :ok = Plumbing.delete_symbolic_ref(repo, "HEAD")

      refute File.exists?(Path.join(path, ".git/HEAD"))
    end

    test "error: posix error (dir where file should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.mkdir_p!(Path.join(xgit_path, ".git/refs/heads/whatever"))

      assert {:error, :cant_delete_file} =
               Plumbing.delete_symbolic_ref(repo, "refs/heads/whatever")
    end

    test "error: posix error (file where dir should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.write!(Path.join(xgit_path, ".git/refs/heads/sub"), "oops, not a directory")

      assert {:error, :cant_delete_file} =
               Plumbing.delete_symbolic_ref(repo, "refs/heads/sub/master")
    end

    test "matches command-line output" do
      %{xgit_path: xgit_path, xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()
      %{xgit_path: ref_path} = OnDiskRepoTestCase.repo!()

      :ok = Plumbing.put_symbolic_ref(xgit_repo, "refs/heads/source", "refs/heads/other")

      {_, 0} =
        System.cmd("git", ["symbolic-ref", "refs/heads/source", "refs/heads/other"], cd: ref_path)

      assert_folders_are_equal(ref_path, xgit_path)

      {_, 0} = System.cmd("git", ["symbolic-ref", "--delete", "refs/heads/source"], cd: ref_path)

      assert :ok = Plumbing.delete_symbolic_ref(xgit_repo, "refs/heads/source")

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        Plumbing.delete_symbolic_ref("xgit repo", "HEAD")
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert {:error, :invalid_repository} = Plumbing.delete_symbolic_ref(not_repo, "HEAD")
    end
  end
end
