defmodule Xgit.Repository.Plumbing.GetSymbolicRefTest do
  use ExUnit.Case, async: true

  alias Xgit.Repository.InvalidRepositoryError
  alias Xgit.Repository.Plumbing
  alias Xgit.Test.OnDiskRepoTestCase

  describe "get_symbolic_ref/2" do
    test "happy path: default HEAD branch points to master" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()
      assert {:ok, "refs/heads/master"} = Plumbing.get_symbolic_ref(repo, "HEAD")
    end

    test "happy path: HEAD branch points to non-existent branch" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert :ok = Plumbing.put_symbolic_ref(repo, "HEAD", "refs/heads/nope")

      assert {:ok, "refs/heads/nope"} = Plumbing.get_symbolic_ref(repo, "HEAD")
    end

    test "error: not a symbolic references" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        Plumbing.hash_object('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert :ok = Plumbing.update_ref(repo, "HEAD", commit_id_master)

      assert {:error, :not_symbolic_ref} = Plumbing.get_symbolic_ref(repo, "refs/heads/master")
    end

    test "error: posix error (dir where file should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.mkdir_p!(Path.join(xgit_path, ".git/refs/heads/whatever"))

      assert {:error, :eisdir} = Plumbing.get_symbolic_ref(repo, "refs/heads/whatever")
    end

    test "error: posix error (file where dir should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.write!(Path.join(xgit_path, ".git/refs/heads/sub"), "oops, not a directory")

      assert {:error, :not_found} = Plumbing.get_symbolic_ref(repo, "refs/heads/sub/master")
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        Plumbing.get_symbolic_ref("xgit repo", "HEAD")
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        Plumbing.get_symbolic_ref(not_repo, "HEAD")
      end
    end
  end
end
