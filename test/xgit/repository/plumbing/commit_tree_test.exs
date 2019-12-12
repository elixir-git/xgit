defmodule Xgit.Repository.Plumbing.CommitTreeTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Object
  alias Xgit.Core.PersonIdent
  alias Xgit.Repository.Plumbing
  alias Xgit.Repository.Storage
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  import Xgit.Test.OnDiskRepoTestCase,
    only: [setup_with_valid_tree!: 0, setup_with_valid_parent_commit!: 0]

  describe "run/2" do
    @valid_pi %PersonIdent{
      name: "A. U. Thor",
      email: "author@example.com",
      when: 1_142_878_449_000,
      tz_offset: 150
    }

    @env OnDiskRepoTestCase.sample_commit_env()

    test "happy path: no parents" do
      %{xgit_path: ref_path, tree_id: tree_id} = setup_with_valid_tree!()

      assert {ref_commit_id_str, 0} =
               System.cmd("git", ["commit-tree", tree_id, "-m", "xxx"], cd: ref_path, env: @env)

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, tree_id: ^tree_id} = setup_with_valid_tree!()

      assert {:ok, commit_id} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 message: 'xxx',
                 author: @valid_pi
               )

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "happy path: no parents (line ending provided)" do
      %{xgit_path: ref_path, tree_id: tree_id} = setup_with_valid_tree!()

      assert {ref_commit_id_str, 0} =
               System.cmd("git", ["commit-tree", tree_id, "-m", "xxx"], cd: ref_path, env: @env)

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, tree_id: ^tree_id} = setup_with_valid_tree!()

      assert {:ok, commit_id} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 message: 'xxx\n',
                 author: @valid_pi
               )

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "happy path: one parent" do
      %{xgit_path: ref_path, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {ref_commit_id_str, 0} =
               System.cmd("git", ["commit-tree", tree_id, "-m", "mumble", "-p", parent_id],
                 cd: ref_path,
                 env: @env
               )

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, tree_id: ^tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {:ok, commit_id} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id],
                 message: 'mumble',
                 author: @valid_pi
               )

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "happy path: duplicate parents" do
      %{xgit_path: ref_path, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {ref_commit_id_str, 0} =
               System.cmd(
                 "git",
                 ["commit-tree", tree_id, "-m", "mumble", "-p", parent_id, "-p", parent_id],
                 cd: ref_path,
                 env: @env,
                 stderr_to_stdout: true
               )

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, tree_id: ^tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {:ok, commit_id} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id, parent_id],
                 message: 'mumble',
                 author: @valid_pi
               )

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "happy path: multiple parents" do
      %{xgit_path: ref_path, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      {parent2_id_str, 0} =
        System.cmd(
          "git",
          [
            "commit-tree",
            "-m",
            "second",
            tree_id
          ],
          cd: ref_path,
          env: @env
        )

      parent2_id = String.trim(parent2_id_str)

      assert {ref_commit_id_str, 0} =
               System.cmd(
                 "git",
                 ["commit-tree", tree_id, "-m", "mumble", "-p", parent_id, "-p", parent2_id],
                 cd: ref_path,
                 env: @env
               )

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, tree_id: ^tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      {parent2_id_str, 0} =
        System.cmd(
          "git",
          [
            "commit-tree",
            "-m",
            "second",
            tree_id
          ],
          cd: xgit_path,
          env: @env
        )

      parent2_id = String.trim(parent2_id_str)

      assert {:ok, commit_id} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id, parent2_id],
                 message: 'mumble',
                 author: @valid_pi
               )

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "error: invalid repo" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert {:error, :invalid_repository} =
               Plumbing.commit_tree(not_repo,
                 tree: "9d252945c1d3c553a30361214db02892d1ea4876",
                 author: @valid_pi
               )
    end

    test "error: invalid tree object ID" do
      %{xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :invalid_tree} =
               Plumbing.commit_tree(xgit_repo,
                 tree: "9d252945c1d3c553a30361214db02892d1ea487",
                 author: @valid_pi
               )
    end

    test "error: tree object doesn't exist" do
      %{xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :invalid_tree} =
               Plumbing.commit_tree(xgit_repo,
                 tree: "9d252945c1d3c553a30361214db02892d1ea4876",
                 author: @valid_pi
               )
    end

    test "error: tree object isn't a tree" do
      %{xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()

      object = %Object{
        type: :blob,
        content: 'test content\n',
        size: 13,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
      }

      :ok = Storage.put_loose_object(xgit_repo, object)

      assert {:error, :invalid_tree} =
               Plumbing.commit_tree(xgit_repo,
                 tree: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
                 author: @valid_pi
               )
    end

    test "error: parents isn't a list" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parents} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: "mom and dad",
                 author: @valid_pi
               )
    end

    test "error: parents is a list of invalid object IDs 1" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parent_ids} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: ["mom and dad"],
                 author: @valid_pi
               )
    end

    test "error: parents is a list of invalid object IDs 2" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parent_ids} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: ['e2f6b54e68192566b90a0ed123fcdcf14a58a421'],
                 author: @valid_pi
               )
    end

    test "error: parents refers to a commit that doesn't exist" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parent_ids} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: ["e2f6b54e68192566b90a0ed123fcdcf14a58a421"],
                 author: @valid_pi
               )
    end

    test "error: parents refers to a commit that isn't a commit" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parent_ids} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [tree_id],
                 author: @valid_pi
               )
    end

    test "error: message isn't a list" do
      %{xgit_repo: xgit_repo, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {:error, :invalid_message} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id],
                 message: "message",
                 author: @valid_pi
               )
    end

    test "error: message isn't a byte list" do
      %{xgit_repo: xgit_repo, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {:error, :invalid_message} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id],
                 message: 'abc' ++ [false],
                 author: @valid_pi
               )
    end

    test "error: author isn't a PersonIdent struct" do
      %{xgit_repo: xgit_repo, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {:error, :invalid_author} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id],
                 message: 'message',
                 author: "A. U. Thor <author@example.com> Sat Oct 5 21:32:49 2019 -0700",
                 committer: @valid_pi
               )
    end

    test "error: author isn't a valid PersonIdent struct" do
      %{xgit_repo: xgit_repo, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {:error, :invalid_author} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id],
                 message: 'message',
                 author: Map.put(@valid_pi, :tz_offset, 15_000),
                 committer: @valid_pi
               )
    end

    test "error: committer isn't a PersonIdent struct" do
      %{xgit_repo: xgit_repo, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {:error, :invalid_committer} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id],
                 message: 'message',
                 author: @valid_pi,
                 committer: "A. U. Thor <author@example.com> Sat Oct 5 21:32:49 2019 -0700"
               )
    end

    test "error: committer isn't a valid PersonIdent struct" do
      %{xgit_repo: xgit_repo, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {:error, :invalid_committer} =
               Plumbing.commit_tree(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id],
                 message: 'message',
                 author: @valid_pi,
                 committer: Map.put(@valid_pi, :tz_offset, 15_000)
               )
    end
  end
end
