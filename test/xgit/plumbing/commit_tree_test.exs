defmodule Xgit.Plumbing.CommitTreeTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Object
  alias Xgit.Core.PersonIdent
  alias Xgit.Plumbing.CommitTree
  alias Xgit.Plumbing.HashObject
  alias Xgit.Plumbing.UpdateIndex.CacheInfo
  alias Xgit.Plumbing.WriteTree
  alias Xgit.Repository
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  describe "run/2" do
    @valid_pi %PersonIdent{
      name: "A. U. Thor",
      email: "author@example.com",
      when: 1_142_878_449_000,
      tz_offset: 150
    }

    @env [
      {"GIT_AUTHOR_DATE", "1142878449 +0230"},
      {"GIT_COMMITTER_DATE", "1142878449 +0230"},
      {"GIT_AUTHOR_EMAIL", "author@example.com"},
      {"GIT_COMMITTER_EMAIL", "author@example.com"},
      {"GIT_AUTHOR_NAME", "A. U. Thor"},
      {"GIT_COMMITTER_NAME", "A. U. Thor"}
    ]

    test "happy path: no parents" do
      %{xgit_path: ref_path, tree_id: tree_id} = setup_with_valid_tree!()

      assert {ref_commit_id_str, 0} =
               System.cmd("git", ["commit-tree", tree_id, "-m", "xxx"], cd: ref_path, env: @env)

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, tree_id: ^tree_id} = setup_with_valid_tree!()

      assert {:ok, commit_id} =
               CommitTree.run(xgit_repo,
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
               CommitTree.run(xgit_repo,
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
               CommitTree.run(xgit_repo,
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
               CommitTree.run(xgit_repo,
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
               CommitTree.run(xgit_repo,
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
               CommitTree.run(not_repo,
                 tree: "9d252945c1d3c553a30361214db02892d1ea4876",
                 author: @valid_pi
               )
    end

    test "error: invalid tree object ID" do
      %{xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :invalid_tree} =
               CommitTree.run(xgit_repo,
                 tree: "9d252945c1d3c553a30361214db02892d1ea487",
                 author: @valid_pi
               )
    end

    test "error: tree object doesn't exist" do
      %{xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :invalid_tree} =
               CommitTree.run(xgit_repo,
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

      :ok = Repository.put_loose_object(xgit_repo, object)

      assert {:error, :invalid_tree} =
               CommitTree.run(xgit_repo,
                 tree: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
                 author: @valid_pi
               )
    end

    test "error: parents isn't a list" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parents} =
               CommitTree.run(xgit_repo,
                 tree: tree_id,
                 parents: "mom and dad",
                 author: @valid_pi
               )
    end

    test "error: parents is a list of invalid object IDs 1" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parent_ids} =
               CommitTree.run(xgit_repo,
                 tree: tree_id,
                 parents: ["mom and dad"],
                 author: @valid_pi
               )
    end

    test "error: parents is a list of invalid object IDs 2" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parent_ids} =
               CommitTree.run(xgit_repo,
                 tree: tree_id,
                 parents: ['e2f6b54e68192566b90a0ed123fcdcf14a58a421'],
                 author: @valid_pi
               )
    end

    test "error: parents refers to a commit that doesn't exist" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parent_ids} =
               CommitTree.run(xgit_repo,
                 tree: tree_id,
                 parents: ["e2f6b54e68192566b90a0ed123fcdcf14a58a421"],
                 author: @valid_pi
               )
    end

    test "error: parents refers to a commit that isn't a commit" do
      %{xgit_repo: xgit_repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {:error, :invalid_parent_ids} =
               CommitTree.run(xgit_repo,
                 tree: tree_id,
                 parents: [tree_id],
                 author: @valid_pi
               )
    end

    test "error: message isn't a list" do
      %{xgit_repo: xgit_repo, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {:error, :invalid_message} =
               CommitTree.run(xgit_repo,
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
               CommitTree.run(xgit_repo,
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
               CommitTree.run(xgit_repo,
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
               CommitTree.run(xgit_repo,
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
               CommitTree.run(xgit_repo,
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
               CommitTree.run(xgit_repo,
                 tree: tree_id,
                 parents: [parent_id],
                 message: 'message',
                 author: @valid_pi,
                 committer: Map.put(@valid_pi, :tz_offset, 15_000)
               )
    end

    defp setup_with_valid_tree!(path \\ nil) do
      %{xgit_repo: xgit_repo} = context = OnDiskRepoTestCase.repo!(path)

      {:ok, object_id} = HashObject.run("test content\n", repo: xgit_repo, write?: true)
      :ok = CacheInfo.run(xgit_repo, [{0o100644, object_id, 'test'}])

      {:ok, xgit_tree_id} = WriteTree.run(xgit_repo)

      Map.put(context, :tree_id, xgit_tree_id)
    end

    defp setup_with_valid_parent_commit! do
      %{xgit_path: xgit_path} = context = setup_with_valid_tree!()

      {empty_tree_id_str, 0} =
        System.cmd(
          "git",
          [
            "write-tree"
          ],
          cd: xgit_path
        )

      empty_tree_id = String.trim(empty_tree_id_str)

      {parent_id_str, 0} =
        System.cmd(
          "git",
          [
            "commit-tree",
            "-m",
            "empty",
            empty_tree_id
          ],
          cd: xgit_path,
          env: @env
        )

      parent_id = String.trim(parent_id_str)

      Map.put(context, :parent_id, parent_id)
    end
  end
end
