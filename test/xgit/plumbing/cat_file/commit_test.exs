defmodule Xgit.Plumbing.CatFile.CommitTest do
  use Xgit.Test.OnDiskRepoTestCase, async: true

  alias Xgit.Core.Commit
  alias Xgit.Core.PersonIdent
  alias Xgit.Plumbing.CatFile.Commit, as: CatFileCommit
  alias Xgit.Plumbing.HashObject
  alias Xgit.Repository.InMemory
  alias Xgit.Test.OnDiskRepoTestCase

  @env OnDiskRepoTestCase.sample_commit_env()

  import Xgit.Test.OnDiskRepoTestCase

  describe "run/2" do
    test "command-line interop: no parents" do
      %{xgit_path: path, xgit_repo: repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {commit_id_str, 0} =
               System.cmd("git", ["commit-tree", tree_id, "-m", "xxx"], cd: path, env: @env)

      commit_id = String.trim(commit_id_str)

      assert {:ok,
              %Commit{
                author: %PersonIdent{
                  email: "author@example.com",
                  name: "A. U. Thor",
                  tz_offset: 150,
                  when: 1_142_878_449
                },
                committer: %PersonIdent{
                  email: "author@example.com",
                  name: "A. U. Thor",
                  tz_offset: 150,
                  when: 1_142_878_449
                },
                message: 'xxx\n',
                parents: [],
                tree: "3e69f02f3247843b482cc99872683692999f6703"
              }} = CatFileCommit.run(repo, commit_id)
    end

    test "command-line interop: one parent" do
      %{xgit_path: path, xgit_repo: repo, tree_id: tree_id, parent_id: parent_id} =
        setup_with_valid_parent_commit!()

      assert {commit_id_str, 0} =
               System.cmd("git", ["commit-tree", tree_id, "-m", "mumble", "-p", parent_id],
                 cd: path,
                 env: @env
               )

      commit_id = String.trim(commit_id_str)

      assert {:ok,
              %Commit{
                author: %PersonIdent{
                  email: "author@example.com",
                  name: "A. U. Thor",
                  tz_offset: 150,
                  when: 1_142_878_449
                },
                committer: %PersonIdent{
                  email: "author@example.com",
                  name: "A. U. Thor",
                  tz_offset: 150,
                  when: 1_142_878_449
                },
                message: 'mumble\n',
                parents: [^parent_id],
                tree: "3e69f02f3247843b482cc99872683692999f6703"
              }} = CatFileCommit.run(repo, commit_id)
    end

    defp write_commit_and_cat_file!(commit_text) do
      %{xgit_repo: xgit_repo} = repo!()

      {:ok, commit_id} =
        HashObject.run(commit_text, repo: xgit_repo, type: :commit, validate?: false, write?: true)

      CatFileCommit.run(xgit_repo, commit_id)
    end

    test "valid: message" do
      assert {:ok,
              %Xgit.Core.Commit{
                author: %Xgit.Core.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: 0,
                  when: 1
                },
                committer: %Xgit.Core.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: 0,
                  when: 1
                },
                message: 'abc\ndef\n',
                parents: [],
                tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
              }} =
               write_commit_and_cat_file!(~C"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author A. U. Thor <author@localhost> 1 +0000
               committer A. U. Thor <author@localhost> 1 +0000

               abc
               def
               """)
    end

    test "invalid: unknown headers" do
      # TO DO: Support signatures and other extensions.
      # https://github.com/elixir-git/xgit/issues/202

      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~C"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author A. U. Thor <author@localhost> 1 +0000
               committer A. U. Thor <author@localhost> 1 +0000
               abc
               def
               """)
    end

    test "valid: blank author" do
      assert {:ok,
              %Xgit.Core.Commit{
                author: %Xgit.Core.PersonIdent{
                  email: "",
                  name: "",
                  tz_offset: 0,
                  when: 0
                },
                committer: %Xgit.Core.PersonIdent{
                  email: "",
                  name: "",
                  tz_offset: 0,
                  when: 0
                },
                message: [],
                parents: [],
                tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
              }} =
               write_commit_and_cat_file!(~C"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author <> 0 +0000
               committer <> 0 +0000
               """)
    end

    test "invalid: corrupt author" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~C"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b789
               author <> 0 +0000
               committer <> 0 +0000
               """)
    end

    test "fuzzy, but valid: corrupt committer" do
      assert {:ok,
              %Xgit.Core.Commit{
                author: %Xgit.Core.PersonIdent{
                  email: "a@b.com",
                  name: "",
                  tz_offset: 0,
                  when: 0
                },
                committer: %Xgit.Core.PersonIdent{
                  email: "b@c",
                  name: "b",
                  tz_offset: 0,
                  when: 0
                },
                message: '',
                parents: [],
                tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
              }} =
               write_commit_and_cat_file!(~C"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author <a@b.com> 0 +0000
               committer b <b@c> <b@c> 0 +0000
               """)
    end

    test "valid: one parent" do
      assert {:ok,
              %Xgit.Core.Commit{
                author: %Xgit.Core.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: 0,
                  when: 1
                },
                committer: %Xgit.Core.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: 0,
                  when: 1
                },
                message: [],
                parents: ["be9bfa841874ccc9f2ef7c48d0c76226f89b7189"],
                tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
              }} =
               write_commit_and_cat_file!(~C"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author A. U. Thor <author@localhost> 1 +0000
               committer A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "valid: two parents" do
      assert {:ok,
              %Xgit.Core.Commit{
                author: %Xgit.Core.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: 0,
                  when: 1
                },
                committer: %Xgit.Core.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: 0,
                  when: 1
                },
                message: [],
                parents: [
                  "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                  "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
                ],
                tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
              }} =
               write_commit_and_cat_file!(~C"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author A. U. Thor <author@localhost> 1 +0000
               committer A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "valid: normal time" do
      assert {:ok,
              %Xgit.Core.Commit{
                author: %Xgit.Core.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: -450,
                  when: 1_222_757_360
                },
                committer: %Xgit.Core.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: -450,
                  when: 1_222_757_360
                },
                message: [],
                parents: [],
                tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
              }} =
               write_commit_and_cat_file!(~C"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author A. U. Thor <author@localhost> 1222757360 -0730
               committer A. U. Thor <author@localhost> 1222757360 -0730
               """)
    end

    test "invalid: no tree 1" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~C"""
               parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: no tree 2" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~C"""
               trie be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: no tree 3" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~C"""
               treebe9bfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: no tree 4" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree\tbe9bfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: invalid tree 1" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree zzzzfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: invalid tree 2" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189z
               """)
    end

    test "invalid: invalid tree 3" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9b
               """)
    end

    test "invalid: invalid tree 4" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree  be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: invalid parent 1" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(
                 'tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                   'parent \n'
               )
    end

    test "invalid: invalid parent 2" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               parent zzzzfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: invalid parent 3" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               parent  be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: invalid parent 4" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               parent  be9bfa841874ccc9f2ef7c48d0c76226f89b7189z
               """)
    end

    test "invalid: invalid parent 5" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               parent\tbe9bfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: no author" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               committer A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "invalid: no committer 1" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "invalid: no committer 2" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author A. U. Thor <author@localhost> 1 +0000

               """)
    end

    test "invalid: invalid author 1" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author A. U. Thor <foo 1 +0000
               """)
    end

    test "invalid: invalid author 2" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author A. U. Thor foo> 1 +0000
               """)
    end

    test "invalid: invalid author 3" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author 1 +0000
               """)
    end

    test "invalid: invalid author 4" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author a <b> +0000
               """)
    end

    test "invalid: invalid author 5" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author a <b>
               """)
    end

    test "invalid: invalid author 6" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author a <b> z
               """)
    end

    test "invalid: invalid author 7" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(~c"""
               tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               author a <b> 1 z
               """)
    end

    test "invalid: invalid committer" do
      assert {:error, :invalid_commit} =
               write_commit_and_cat_file!(
                 'tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                   'author a <b> 1 +0000\n' ++
                   'committer a <'
               )
    end

    test "error: not_found" do
      {:ok, repo} = InMemory.start_link()

      assert {:error, :not_found} =
               CatFileCommit.run(repo, "6c22d81cc51c6518e4625a9fe26725af52403b4f")
    end

    test "error: invalid_object", %{xgit_repo: xgit_repo, xgit_path: xgit_path} do
      path = Path.join([xgit_path, ".git", "objects", "5c"])
      File.mkdir_p!(path)

      File.write!(
        Path.join(path, "b5d77be2d92c7368038dac67e648a69e0a654d"),
        <<120, 1, 75, 202, 201, 79, 170, 80, 48, 52, 50, 54, 97, 0, 0, 22, 54, 3, 2>>
      )

      assert {:error, :invalid_object} =
               CatFileCommit.run(xgit_repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
    end

    test "error: not_a_commit", %{xgit_repo: xgit_repo, xgit_path: xgit_path} do
      Temp.track!()
      path = Temp.path!()

      File.write!(path, "test content\n")

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: xgit_path)
      object_id = String.trim(output)

      assert {:error, :not_a_commit} = CatFileCommit.run(xgit_repo, object_id)
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        CatFileCommit.run("xgit repo", "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert {:error, :invalid_repository} =
               CatFileCommit.run(not_repo, "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
    end

    test "error: object_id invalid (not binary)" do
      {:ok, repo} = InMemory.start_link()

      assert_raise FunctionClauseError, fn ->
        CatFileCommit.run(repo, 0x18A4)
      end
    end

    test "error: object_id invalid (binary, but not valid object ID)" do
      {:ok, repo} = InMemory.start_link()

      assert {:error, :invalid_object_id} =
               CatFileCommit.run(repo, "some random ID that isn't valid")
    end
  end
end
