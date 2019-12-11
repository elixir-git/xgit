defmodule Xgit.Plumbing.UpdateRefTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Core.Ref
  alias Xgit.Plumbing.HashObject
  alias Xgit.Plumbing.UpdateRef
  alias Xgit.Repository.Storage
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  @env OnDiskRepoTestCase.sample_commit_env()

  describe "run/4" do
    test "error: object does not exist" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :target_not_found} =
               UpdateRef.run(
                 repo,
                 "refs/heads/master",
                 "532ad3cb2518ad13a91e717998a26a6028df0623"
               )
    end

    @test_content 'test content\n'
    @test_content_id "d670460b4b4aece5915caf5c68d12f560a9fe3e4"

    test "error: object exists, but is not a commit" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      :ok = Storage.put_loose_object(repo, object)

      assert {:error, :target_not_commit} =
               UpdateRef.run(repo, "refs/heads/master", @test_content_id)
    end

    test "error: posix error (dir where file should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.mkdir_p!(Path.join(xgit_path, ".git/refs/heads/master"))

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert {:error, :eisdir} = UpdateRef.run(repo, "refs/heads/master", commit_id_master)
    end

    test "error: posix error (file where dir should be)" do
      %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

      File.write!(Path.join(xgit_path, ".git/refs/heads/sub"), "oops, not a directory")

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert {:error, :eexist} = UpdateRef.run(repo, "refs/heads/sub/master", commit_id_master)
    end

    test "happy path" do
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

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master)

      assert {:ok, [^master_ref]} = Storage.list_refs(repo)

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

      assert :ok = UpdateRef.run(repo, "refs/heads/other", commit_id_other)

      assert {:ok, ^master_ref} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, ^other_ref} = Storage.get_ref(repo, "refs/heads/other")

      assert {:ok, [^master_ref, ^other_ref]} = Storage.list_refs(repo)
    end

    test "follows HEAD reference" do
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

      master_ref_via_head = %Ref{
        name: "HEAD",
        target: commit_id_master,
        link_target: "refs/heads/master"
      }

      assert :ok = UpdateRef.run(repo, "HEAD", commit_id_master)

      assert {:ok, [^master_ref]} = Storage.list_refs(repo)
      assert {:ok, ^master_ref} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, ^master_ref_via_head} = Storage.get_ref(repo, "HEAD")
    end

    test "result can be read by command-line git" do
      %{xgit_repo: repo, xgit_path: path} = OnDiskRepoTestCase.repo!()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master)

      {:ok, commit_id_other} =
        HashObject.run('shhh... another fake commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert :ok = UpdateRef.run(repo, "refs/heads/other", commit_id_other)

      show_ref_output = ~s"""
      #{commit_id_master} refs/heads/master
      #{commit_id_other} refs/heads/other
      """

      assert {^show_ref_output, 0} = System.cmd("git", ["show-ref"], cd: path)
    end

    test "matches command-line output" do
      %{xgit_path: xgit_path, xgit_repo: xgit_repo, parent_id: xgit_commit_id} =
        OnDiskRepoTestCase.setup_with_valid_parent_commit!()

      %{xgit_path: ref_path, parent_id: ref_commit_id} =
        OnDiskRepoTestCase.setup_with_valid_parent_commit!()

      {_, 0} = System.cmd("git", ["update-ref", "refs/heads/other", ref_commit_id], cd: ref_path)

      :ok = UpdateRef.run(xgit_repo, "refs/heads/other", xgit_commit_id)

      assert_folders_are_equal(
        Path.join([ref_path, ".git", "refs"]),
        Path.join([xgit_path, ".git", "refs"])
      )
    end

    test ":old_target (correct match)" do
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

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master)
      assert {:ok, [^master_ref]} = Storage.list_refs(repo)

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

      assert :ok =
               UpdateRef.run(repo, "refs/heads/master", commit_id2_master,
                 old_target: commit_id_master
               )

      assert {:ok, [^master_ref2]} = Storage.list_refs(repo)
    end

    test ":old_target (incorrect match)" do
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

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master)
      assert {:ok, [^master_ref]} = Storage.list_refs(repo)

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert {:error, :old_target_not_matched} =
               UpdateRef.run(repo, "refs/heads/master", commit_id2_master,
                 old_target: "2075df9dff2b5a10ad417586b4edde66af849bad"
               )

      assert {:ok, [^master_ref]} = Storage.list_refs(repo)
    end

    test ":old_target (does not exist)" do
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

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master)
      assert {:ok, [^master_ref]} = Storage.list_refs(repo)

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert {:error, :old_target_not_matched} =
               UpdateRef.run(repo, "refs/heads/master2", commit_id2_master,
                 old_target: commit_id_master
               )

      assert {:ok, [^master_ref]} = Storage.list_refs(repo)
    end

    test ":old_target = :new" do
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

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master, old_target: :new)
      assert {:ok, [^master_ref]} = Storage.list_refs(repo)
    end

    test ":old_target = :new, but target does exist" do
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

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master)
      assert {:ok, [^master_ref]} = Storage.list_refs(repo)

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      assert {:error, :old_target_not_matched} =
               UpdateRef.run(repo, "refs/heads/master", commit_id2_master, old_target: :new)

      assert {:ok, [^master_ref]} = Storage.list_refs(repo)
    end

    test "target 0000 removes an existing ref" do
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

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master)

      assert {:ok, [^master_ref]} = Storage.list_refs(repo)

      assert :ok = UpdateRef.run(repo, "refs/heads/master", ObjectId.zero())

      assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Storage.list_refs(repo)
    end

    test "target 0000 quietly 'succeeds' if ref didn't exist" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert {:ok, []} = Storage.list_refs(repo)

      assert :ok = UpdateRef.run(repo, "refs/heads/master", ObjectId.zero())

      assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Storage.list_refs(repo)
    end

    test "target 0000 error if name invalid" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert {:ok, []} = Storage.list_refs(repo)

      assert {:error, :invalid_ref} = UpdateRef.run(repo, "refs", ObjectId.zero())

      assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Storage.list_refs(repo)
    end

    test "delete :old_target matches existing ref" do
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

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master)

      assert {:ok, [^master_ref]} = Storage.list_refs(repo)

      assert :ok =
               UpdateRef.run(repo, "refs/heads/master", ObjectId.zero(),
                 old_target: commit_id_master
               )

      assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Storage.list_refs(repo)
    end

    test "delete doesn't remove ref if :old_target doesn't match" do
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

      assert :ok = UpdateRef.run(repo, "refs/heads/master", commit_id_master)

      assert {:ok, [^master_ref]} = Storage.list_refs(repo)

      assert {:error, :old_target_not_matched} =
               UpdateRef.run(repo, "refs/heads/master", ObjectId.zero(),
                 old_target: "bec43c416143e6b8bf9a3b559260185757e1386b"
               )

      assert {:ok, ^master_ref} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, [^master_ref]} = Storage.list_refs(repo)
    end

    test "delete error if :old_target specified and no ref exists" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert {:ok, []} = Storage.list_refs(repo)

      assert {:error, :old_target_not_matched} =
               UpdateRef.run(repo, "refs/heads/master", ObjectId.zero(),
                 old_target: "bec43c416143e6b8bf9a3b559260185757e1386b"
               )

      assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Storage.list_refs(repo)
    end

    test "delete {:error, :cant_delete_file}" do
      %{xgit_repo: repo, xgit_path: path} = OnDiskRepoTestCase.repo!()

      bogus_ref_path = Path.join(path, ".git/refs/heads/bogus")

      File.mkdir_p!(bogus_ref_path)

      assert {:error, :cant_delete_file} =
               UpdateRef.run(repo, "refs/heads/bogus", ObjectId.zero())

      assert File.dir?(bogus_ref_path)
    end

    test "deletion is seen by command-line git" do
      %{xgit_repo: repo, xgit_path: path} = OnDiskRepoTestCase.repo!()

      assert {_, 0} =
               System.cmd("git", ["commit", "--allow-empty", "--message", "foo"],
                 cd: path,
                 env: @env
               )

      {show_ref_output, 0} = System.cmd("git", ["show-ref", "master"], cd: path)
      {commit_id, _} = String.split_at(show_ref_output, 40)

      assert {_, 0} = System.cmd("git", ["update-ref", "refs/heads/other", commit_id], cd: path)
      assert {_, 0} = System.cmd("git", ["show-ref", "refs/heads/other"], cd: path)

      assert :ok = UpdateRef.run(repo, "refs/heads/other", ObjectId.zero())

      assert {_, 1} = System.cmd("git", ["show-ref", "refs/heads/other"], cd: path)
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        UpdateRef.run(
          "xgit repo",
          "refs/heads/master",
          "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0"
        )
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert {:error, :invalid_repository} =
               UpdateRef.run(
                 not_repo,
                 "refs/heads/master",
                 "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0"
               )
    end

    test "error: old_target invalid" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert_raise ArgumentError,
                   ~s(Xgit.Plumbing.UpdateRef.run/4: old_target "bogus" is invalid),
                   fn ->
                     UpdateRef.run(
                       repo,
                       "refs/heads/master",
                       "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0",
                       old_target: "bogus"
                     )
                   end
    end
  end
end
