defmodule Xgit.Repository.OnDisk.RefTest do
  # We test all of the Ref-related tests together.

  use ExUnit.Case, async: true

  alias Xgit.Core.Object
  alias Xgit.Core.Ref
  alias Xgit.Plumbing.HashObject
  alias Xgit.Repository
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  @env OnDiskRepoTestCase.sample_commit_env()

  describe "ref APIs" do
    test "list_refs/1 null case" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()
      assert {:ok, []} = Repository.list_refs(repo)
    end

    test "get_ref/2 not_found case" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()
      assert {:error, :not_found} = Repository.get_ref(repo, "refs/heads/master")
    end

    test "get_ref/2 invalid_name case" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()
      assert {:error, :invalid_name} = Repository.get_ref(repo, "refs/../../heads/master")
    end

    test "get_ref/2 invalid ref (malformed file)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.write!(Path.join(xgit_path, ".git/refs/heads/master"), "not a SHA-1 hash")

      assert {:error, :invalid_ref} = Repository.get_ref(repo, "refs/heads/master")
    end

    test "get_ref/2 invalid ref (dir, not file)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.mkdir_p!(Path.join(xgit_path, ".git/refs/heads/master"))

      assert {:error, :eisdir} = Repository.get_ref(repo, "refs/heads/master")
    end

    test "get_ref/2 invalid ref (empty file)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.write!(Path.join(xgit_path, ".git/refs/heads/master"), "")

      assert {:error, :eof} = Repository.get_ref(repo, "refs/heads/master")
    end

    test "get_ref/2 posix error" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.mkdir_p!(Path.join(xgit_path, ".git/refs/heads/master"))

      assert {:error, :eisdir} = Repository.get_ref(repo, "refs/heads/master")
    end

    test "get_ref/2 can read ref written by command-line git" do
      %{xgit_repo: repo, xgit_path: path} = OnDiskRepoTestCase.repo!()

      assert {_, 0} =
               System.cmd("git", ["commit", "--allow-empty", "--message", "foo"],
                 cd: path,
                 env: @env
               )

      {show_ref_output, 0} = System.cmd("git", ["show-ref", "master"], cd: path)
      {commit_id, _} = String.split_at(show_ref_output, 40)

      assert {_, 0} = System.cmd("git", ["update-ref", "refs/heads/other", commit_id], cd: path)

      other_ref = %Ref{
        name: "refs/heads/other",
        target: commit_id
      }

      assert {:ok, ^other_ref} = Repository.get_ref(repo, "refs/heads/other")
    end

    test "put_ref/2 object must exist" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :target_not_found} =
               Repository.put_ref(repo, %Ref{
                 name: "refs/heads/master",
                 target: "532ad3cb2518ad13a91e717998a26a6028df0623"
               })
    end

    @test_content 'test content\n'
    @test_content_id "d670460b4b4aece5915caf5c68d12f560a9fe3e4"

    test "put_ref/2 object exists, but is not a commit" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      :ok = Repository.put_loose_object(repo, object)

      assert {:error, :target_not_commit} =
               Repository.put_ref(repo, %Ref{
                 name: "refs/heads/master",
                 target: @test_content_id
               })
    end

    test "put_ref/2 posix error (dir where file should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.mkdir_p!(Path.join(xgit_path, ".git/refs/heads/master"))

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert {:error, :eisdir} =
               Repository.put_ref(repo, %Ref{
                 name: "refs/heads/master",
                 target: commit_id_master
               })
    end

    test "put_ref/2 posix error (file where dir should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.write!(Path.join(xgit_path, ".git/refs/heads/sub"), "oops, not a directory")

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert {:error, :eexist} =
               Repository.put_ref(repo, %Ref{
                 name: "refs/heads/sub/master",
                 target: commit_id_master
               })
    end

    test "put_ref/2 followed by list and get" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      assert :ok = Repository.put_ref(repo, master_ref)

      assert {:ok, [^master_ref]} = Repository.list_refs(repo)

      {:ok, commit_id_other} =
        HashObject.run('shhh... another fake commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      other_ref = %Ref{
        name: "refs/heads/other",
        target: commit_id_other
      }

      assert :ok = Repository.put_ref(repo, other_ref)

      assert {:ok, ^master_ref} = Repository.get_ref(repo, "refs/heads/master")
      assert {:ok, ^other_ref} = Repository.get_ref(repo, "refs/heads/other")

      assert {:ok, [^master_ref, ^other_ref]} = Repository.list_refs(repo)
    end

    test "list_refs/1 skips malformed file" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      assert :ok = Repository.put_ref(repo, master_ref)

      File.write!(Path.join(xgit_path, ".git/refs/heads/other"), "not a SHA-1 hash")

      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end

    test "put_ref/2 can be read by command-line git" do
      %{xgit_repo: repo, xgit_path: path} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      assert :ok = Repository.put_ref(repo, master_ref)

      {:ok, commit_id_other} =
        HashObject.run('shhh... another fake commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      other_ref = %Ref{
        name: "refs/heads/other",
        target: commit_id_other
      }

      assert :ok = Repository.put_ref(repo, other_ref)

      show_ref_output = ~s"""
      #{commit_id_master} refs/heads/master
      #{commit_id_other} refs/heads/other
      """

      assert {^show_ref_output, 0} = System.cmd("git", ["show-ref"], cd: path)
    end

    test "put_ref/2 matches command-line output" do
      %{xgit_path: xgit_path, xgit_repo: xgit_repo, parent_id: xgit_commit_id} =
        OnDiskRepoTestCase.setup_with_valid_parent_commit!()

      %{xgit_path: ref_path, parent_id: ref_commit_id} =
        OnDiskRepoTestCase.setup_with_valid_parent_commit!()

      {_, 0} = System.cmd("git", ["update-ref", "refs/heads/other", ref_commit_id], cd: ref_path)

      :ok = Repository.put_ref(xgit_repo, %Ref{name: "refs/heads/other", target: xgit_commit_id})

      assert_folders_are_equal(
        Path.join([ref_path, ".git", "refs"]),
        Path.join([xgit_path, ".git", "refs"])
      )
    end

    test "put_ref: :old_target (correct match)" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      assert :ok = Repository.put_ref(repo, master_ref)
      assert {:ok, [^master_ref]} = Repository.list_refs(repo)

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref2 = %Ref{
        name: "refs/heads/master",
        target: commit_id2_master
      }

      assert :ok = Repository.put_ref(repo, master_ref2, old_target: commit_id_master)
      assert {:ok, [^master_ref2]} = Repository.list_refs(repo)
    end

    test "put_ref: :old_target (incorrect match)" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      assert :ok = Repository.put_ref(repo, master_ref)
      assert {:ok, [^master_ref]} = Repository.list_refs(repo)

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref2 = %Ref{
        name: "refs/heads/master",
        target: commit_id2_master
      }

      assert {:error, :old_target_not_matched} =
               Repository.put_ref(repo, master_ref2,
                 old_target: "2075df9dff2b5a10ad417586b4edde66af849bad"
               )

      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end

    test "put_ref: :old_target (does not exist)" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      assert :ok = Repository.put_ref(repo, master_ref)
      assert {:ok, [^master_ref]} = Repository.list_refs(repo)

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref2 = %Ref{
        name: "refs/heads/master2",
        target: commit_id2_master
      }

      assert {:error, :old_target_not_matched} =
               Repository.put_ref(repo, master_ref2, old_target: commit_id_master)

      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end

    test "put_ref: :old_target = :new" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      assert :ok = Repository.put_ref(repo, master_ref, old_target: :new)
      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end

    test "put_ref: :old_target = :new, but target does exist" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      assert :ok = Repository.put_ref(repo, master_ref)
      assert {:ok, [^master_ref]} = Repository.list_refs(repo)

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref2 = %Ref{
        name: "refs/heads/master",
        target: commit_id2_master
      }

      assert {:error, :old_target_not_matched} =
               Repository.put_ref(repo, master_ref2, old_target: :new)

      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end
  end
end
