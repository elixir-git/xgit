defmodule Xgit.Repository.Plumbing.PutSymbolicRefTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Ref
  alias Xgit.Repository.Plumbing
  alias Xgit.Repository.Storage
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  describe "put_symbolic_ref/4" do
    test "happy path: target ref does not exist" do
      %{xgit_path: path, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert :ok = Plumbing.put_symbolic_ref(repo, "HEAD", "refs/heads/nope")

      assert {"refs/heads/nope\n", 0} = System.cmd("git", ["symbolic-ref", "HEAD"], cd: path)
    end

    test "error: posix error (dir where file should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.mkdir_p!(Path.join(xgit_path, ".git/refs/heads/whatever"))

      assert {:error, :eisdir} =
               Plumbing.put_symbolic_ref(repo, "refs/heads/whatever", "refs/heads/master")
    end

    test "error: posix error (file where dir should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.write!(Path.join(xgit_path, ".git/refs/heads/sub"), "oops, not a directory")

      assert {:error, :eexist} =
               Plumbing.put_symbolic_ref(repo, "refs/heads/sub/master", "refs/heads/master")
    end

    test "follows HEAD reference after it changes" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        Plumbing.hash_object('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      master_ref_via_head = %Ref{
        name: "HEAD",
        target: commit_id_master,
        link_target: "refs/heads/master"
      }

      assert :ok = Plumbing.update_ref(repo, "HEAD", commit_id_master)

      assert {:ok, [^master_ref]} = Storage.list_refs(repo)
      assert {:ok, ^master_ref} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, ^master_ref_via_head} = Storage.get_ref(repo, "HEAD")

      {:ok, commit_id_other} =
        Plumbing.hash_object('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      other_ref = %Ref{
        name: "refs/heads/other",
        target: commit_id_other
      }

      other_ref_via_head = %Ref{
        name: "HEAD",
        target: commit_id_other,
        link_target: "refs/heads/other"
      }

      assert :ok = Plumbing.put_symbolic_ref(repo, "HEAD", "refs/heads/other")

      assert :ok = Plumbing.update_ref(repo, "HEAD", commit_id_other)

      assert {:ok, [^master_ref, ^other_ref]} = Storage.list_refs(repo)
      assert {:ok, ^master_ref} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, ^other_ref_via_head} = Storage.get_ref(repo, "HEAD")
    end

    test "result can be read by command-line git" do
      %{xgit_repo: repo, xgit_path: path} = OnDiskRepoTestCase.repo!()

      assert :ok = Plumbing.put_symbolic_ref(repo, "HEAD", "refs/heads/other")
      assert {"refs/heads/other\n", 0} = System.cmd("git", ["symbolic-ref", "HEAD"], cd: path)
    end

    test "matches command-line output" do
      %{xgit_path: xgit_path, xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()
      %{xgit_path: ref_path} = OnDiskRepoTestCase.repo!()

      {_, 0} = System.cmd("git", ["symbolic-ref", "HEAD", "refs/heads/other"], cd: ref_path)

      :ok = Plumbing.put_symbolic_ref(xgit_repo, "HEAD", "refs/heads/other")

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        Plumbing.put_symbolic_ref("xgit repo", "HEAD", "refs/heads/master")
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert {:error, :invalid_repository} =
               Plumbing.put_symbolic_ref(not_repo, "HEAD", "refs/heads/master")
    end
  end
end
