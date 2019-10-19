defmodule Xgit.Core.CommitTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Commit
  alias Xgit.Core.Object
  alias Xgit.Core.PersonIdent
  alias Xgit.GitInitTestCase
  alias Xgit.Repository
  alias Xgit.Repository.OnDisk
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  import Xgit.Test.OnDiskRepoTestCase,
    only: [setup_with_valid_tree!: 0, setup_with_valid_parent_commit!: 0]

  @valid_pi %PersonIdent{
    name: "A. U. Thor",
    email: "author@example.com",
    when: 1_142_878_501_000,
    tz_offset: 150
  }

  @invalid_pi %PersonIdent{
    name: :bogus,
    email: "author@example.com",
    when: 1_142_878_501_000,
    tz_offset: 150
  }

  @env OnDiskRepoTestCase.sample_commit_env()

  describe "valid?/1" do
    test "valid: no parent" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "valid: blank author" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("<> 0 +0000"),
               committer: pi("<> 0 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt author 1" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: @invalid_pi,
               committer: pi("<> 0 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt author 2" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: "A. U. Thor <author@localhost> 1 +0000",
               committer: pi("<> 0 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt committer 1" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("<> 0 +0000"),
               committer: @invalid_pi,
               message: 'x'
             })
    end

    test "invalid: corrupt committer 2" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("<> 0 +0000"),
               committer: "A. U. Thor <author@localhost> 1 +0000",
               message: 'x'
             })
    end

    test "valid: one parent" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ["be9bfa841874ccc9f2ef7c48d0c76226f89b7189"],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "valid: two parents" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: [
                 "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                 "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
               ],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "valid: 128 parents" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: Enum.map(1..128, fn _ -> "be9bfa841874ccc9f2ef7c48d0c76226f89b7189" end),
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "valid: normal time" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("A. U. Thor <author@localhost> 1222757360 -0730"),
               committer: pi("A. U. Thor <author@localhost> 1222757360 -0730"),
               message: 'x'
             })
    end

    test "invalid: invalid tree 1" do
      refute Commit.valid?(%Commit{
               tree: 'be9bfa841874ccc9f2ef7c48d0c76226f89b7189',
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid tree 2" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b718",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid tree 3" do
      refute Commit.valid?(%Commit{
               tree: "zzz9bfa841874ccc9f2ef7c48d0c76226f89b718",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid parent 1" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ["e9bfa841874ccc9f2ef7c48d0c76226f89b7189"],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid parent 2" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ['be9bfa841874ccc9f2ef7c48d0c76226f89b7189'],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid parent 3" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ["ze9bfa841874ccc9f2ef7c48d0c76226f89b7189"],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid parent 4" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ["Be9bfa841874ccc9f2ef7c48d0c76226f89b7189"],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: no message" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: ''
             })
    end

    test "invalid: message is string" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: "x"
             })
    end

    defp pi(s) do
      s
      |> String.to_charlist()
      |> PersonIdent.from_byte_list()
    end
  end

  describe "from_object/1" do
    test "command-line interop: no parents" do
      %{xgit_path: path, xgit_repo: repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {commit_id_str, 0} =
               System.cmd("git", ["commit-tree", tree_id, "-m", "xxx"], cd: path, env: @env)

      commit_id = String.trim(commit_id_str)

      {:ok, commit_object} = Repository.get_object(repo, commit_id)

      assert {:ok,
              %Xgit.Core.Commit{
                author: %Xgit.Core.PersonIdent{
                  email: "author@example.com",
                  name: "A. U. Thor",
                  tz_offset: 150,
                  when: 1142878449
                },
                committer: %Xgit.Core.PersonIdent{
                  email: "author@example.com",
                  name: "A. U. Thor",
                  tz_offset: 150,
                  when: 1142878449
                },
                message: 'xxx\n',
                parents: [],
                tree: "3e69f02f3247843b482cc99872683692999f6703"
              }} = Commit.from_object(commit_object)
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

      {:ok, commit_object} = Repository.get_object(repo, commit_id)

      assert {:ok,
              %Xgit.Core.Commit{
                author: %Xgit.Core.PersonIdent{
                  email: "author@example.com",
                  name: "A. U. Thor",
                  tz_offset: 150,
                  when: 1142878449
                },
                committer: %Xgit.Core.PersonIdent{
                  email: "author@example.com",
                  name: "A. U. Thor",
                  tz_offset: 150,
                  when: 1142878449
                },
                message: 'mumble\n',
                parents: [^parent_id],
                tree: "3e69f02f3247843b482cc99872683692999f6703"
              }} = Commit.from_object(commit_object)
    end

    test "valid: no parent" do
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
                parents: [],
                tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
              }} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 committer A. U. Thor <author@localhost> 1 +0000
                 """
               })
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
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 committer A. U. Thor <author@localhost> 1 +0000

                 abc
                 def
                 """
               })
    end

    test "invalid: unknown headers" do
      # TO DO: Support signatures and other extensions.
      # https://github.com/elixir-git/xgit/issues/202

      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 committer A. U. Thor <author@localhost> 1 +0000
                 abc
                 def
                 """
               })
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
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author <> 0 +0000
                 committer <> 0 +0000
                 """
               })
    end

    test "invalid: corrupt author" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b789
                 author <> 0 +0000
                 committer <> 0 +0000
                 """
               })
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
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author <a@b.com> 0 +0000
                 committer b <b@c> <b@c> 0 +0000
                 """
               })
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
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 committer A. U. Thor <author@localhost> 1 +0000
                 """
               })
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
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 committer A. U. Thor <author@localhost> 1 +0000
                 """
               })
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
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1222757360 -0730
                 committer A. U. Thor <author@localhost> 1222757360 -0730
                 """
               })
    end

    test "invalid: no tree 1" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no tree 2" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 trie be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no tree 3" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~C"""
                 treebe9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no tree 4" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree\tbe9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid tree 1" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree zzzzfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid tree 2" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189z
                 """
               })
    end

    test "invalid: invalid tree 3" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9b
                 """
               })
    end

    test "invalid: invalid tree 4" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree  be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid parent 1" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content:
                   'tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'parent \n'
               })
    end

    test "invalid: invalid parent 2" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent zzzzfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid parent 3" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent  be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid parent 4" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent  be9bfa841874ccc9f2ef7c48d0c76226f89b7189z
                 """
               })
    end

    test "invalid: invalid parent 5" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent\tbe9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no author" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 committer A. U. Thor <author@localhost> 1 +0000
                 """
               })
    end

    test "invalid: no committer 1" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 """
               })
    end

    test "invalid: no committer 2" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000

                 """
               })
    end

    test "invalid: invalid author 1" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <foo 1 +0000
                 """
               })
    end

    test "invalid: invalid author 2" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor foo> 1 +0000
                 """
               })
    end

    test "invalid: invalid author 3" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author 1 +0000
                 """
               })
    end

    test "invalid: invalid author 4" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author a <b> +0000
                 """
               })
    end

    test "invalid: invalid author 5" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author a <b>
                 """
               })
    end

    test "invalid: invalid author 6" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author a <b> z
                 """
               })
    end

    test "invalid: invalid author 7" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author a <b> 1 z
                 """
               })
    end

    test "invalid: invalid committer" do
      assert {:error, :invalid_commit} =
               Commit.from_object(%Object{
                 type: :commit,
                 content:
                   'tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'author a <b> 1 +0000\n' ++
                     'committer a <'
               })
    end

    test "object is not a commit" do
      object = %Object{
        type: :blob,
        content: 'test content\n',
        size: 13,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
      }

      assert {:error, :not_a_commit} = Commit.from_object(object)
    end
  end

  describe "to_object/1" do
    test "empty tree" do
      assert_same_output(
        fn _git_dir -> [] end,
        fn tree_id, [] ->
          %Commit{
            tree: tree_id,
            author: @valid_pi,
            committer: @valid_pi,
            message: 'x\n'
          }
        end
      )
    end

    test "tree with two entries" do
      assert_same_output(
        fn git_dir ->
          {_output, 0} =
            System.cmd(
              "git",
              [
                "update-index",
                "--add",
                "--cacheinfo",
                "100644",
                "7919e8900c3af541535472aebd56d44222b7b3a3",
                "hello.txt"
              ],
              cd: git_dir
            )

          {_output, 0} =
            System.cmd(
              "git",
              [
                "update-index",
                "--add",
                "--cacheinfo",
                "100755",
                "4a43a489f107e7ece679950f53567c648038449a",
                "xyzzy.sh"
              ],
              cd: git_dir
            )

          []
        end,
        fn tree_id, [] ->
          %Commit{
            tree: tree_id,
            author: @valid_pi,
            committer: @valid_pi,
            message: 'x\n'
          }
        end
      )
    end

    test "tree with two entries and one parent" do
      assert_same_output(
        fn git_dir ->
          {empty_tree_id_str, 0} =
            System.cmd(
              "git",
              [
                "write-tree"
              ],
              cd: git_dir
            )

          empty_tree_id = String.trim(empty_tree_id_str)

          env = [
            {"GIT_AUTHOR_DATE", "1142878449 +0230"},
            {"GIT_COMMITTER_DATE", "1142878449 +0230"},
            {"GIT_AUTHOR_EMAIL", "author@example.com"},
            {"GIT_COMMITTER_EMAIL", "author@example.com"},
            {"GIT_AUTHOR_NAME", "A. U. Thor"},
            {"GIT_COMMITTER_NAME", "A. U. Thor"}
          ]

          {empty_commit_id_str, 0} =
            System.cmd(
              "git",
              [
                "commit-tree",
                "-m",
                "empty",
                empty_tree_id
              ],
              cd: git_dir,
              env: env
            )

          empty_commit_id = String.trim(empty_commit_id_str)

          {_output, 0} =
            System.cmd(
              "git",
              [
                "update-index",
                "--add",
                "--cacheinfo",
                "100644",
                "7919e8900c3af541535472aebd56d44222b7b3a3",
                "hello.txt"
              ],
              cd: git_dir
            )

          {_output, 0} =
            System.cmd(
              "git",
              [
                "update-index",
                "--add",
                "--cacheinfo",
                "100755",
                "4a43a489f107e7ece679950f53567c648038449a",
                "xyzzy.sh"
              ],
              cd: git_dir
            )

          [empty_commit_id]
        end,
        fn tree_id, parents ->
          %Commit{
            tree: tree_id,
            parents: parents,
            author: @valid_pi,
            committer: @valid_pi,
            message: 'x\n'
          }
        end
      )
    end

    test "deduplicates and warns on duplicate parent" do
      assert_same_output(
        fn git_dir ->
          {empty_tree_id_str, 0} =
            System.cmd(
              "git",
              [
                "write-tree"
              ],
              cd: git_dir
            )

          empty_tree_id = String.trim(empty_tree_id_str)

          env = [
            {"GIT_AUTHOR_DATE", "1142878449 +0230"},
            {"GIT_COMMITTER_DATE", "1142878449 +0230"},
            {"GIT_AUTHOR_EMAIL", "author@example.com"},
            {"GIT_COMMITTER_EMAIL", "author@example.com"},
            {"GIT_AUTHOR_NAME", "A. U. Thor"},
            {"GIT_COMMITTER_NAME", "A. U. Thor"}
          ]

          {empty_commit_id_str, 0} =
            System.cmd(
              "git",
              [
                "commit-tree",
                "-m",
                "empty",
                empty_tree_id
              ],
              cd: git_dir,
              env: env
            )

          empty_commit_id = String.trim(empty_commit_id_str)

          {_output, 0} =
            System.cmd(
              "git",
              [
                "update-index",
                "--add",
                "--cacheinfo",
                "100644",
                "7919e8900c3af541535472aebd56d44222b7b3a3",
                "hello.txt"
              ],
              cd: git_dir
            )

          {_output, 0} =
            System.cmd(
              "git",
              [
                "update-index",
                "--add",
                "--cacheinfo",
                "100755",
                "4a43a489f107e7ece679950f53567c648038449a",
                "xyzzy.sh"
              ],
              cd: git_dir
            )

          [empty_commit_id, empty_commit_id]
        end,
        fn tree_id, parents ->
          %Commit{
            tree: tree_id,
            parents: parents,
            author: @valid_pi,
            committer: @valid_pi,
            message: 'x\n'
          }
        end
      )
    end

    test "raises ArgumentError if commit is invalid" do
      assert_raise ArgumentError, "Xgit.Core.Commit.to_object/1: commit is not valid", fn ->
        Commit.to_object(%Commit{
          tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
          author: @invalid_pi,
          committer: pi("<> 0 +0000"),
          message: 'x'
        })
      end
    end

    defp assert_same_output(write_tree_fn, xgit_fn, opts \\ []) do
      author_date = Keyword.get(opts, :author_date, "1142878501 +0230")
      committer_date = Keyword.get(opts, :committer_date, "1142878501 +0230")

      author_name = Keyword.get(opts, :author_name, "A. U. Thor")
      committer_name = Keyword.get(opts, :committer_name, "A. U. Thor")

      author_email = Keyword.get(opts, :author_email, "author@example.com")
      committer_email = Keyword.get(opts, :committer_email, "author@example.com")

      message = Keyword.get(opts, :message, "x")

      env = [
        {"GIT_AUTHOR_DATE", author_date},
        {"GIT_COMMITTER_DATE", committer_date},
        {"GIT_AUTHOR_EMAIL", author_email},
        {"GIT_COMMITTER_EMAIL", committer_email},
        {"GIT_AUTHOR_NAME", author_name},
        {"GIT_COMMITTER_NAME", committer_name}
      ]

      {:ok, ref: ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      ref_parents = write_tree_fn.(ref)

      {output, 0} = System.cmd("git", ["write-tree", "--missing-ok"], cd: ref)
      tree_content_id = String.trim(output)

      {output, 0} =
        System.cmd(
          "git",
          ["commit-tree", tree_content_id, "-m", message] ++
            Enum.flat_map(Enum.uniq(ref_parents), &["-p", &1]),
          cd: ref,
          env: env
        )

      ref_commit_id = String.trim(output)

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      parents = write_tree_fn.(xgit)
      assert parents == ref_parents

      xgit_commit_object =
        tree_content_id
        |> xgit_fn.(parents)
        |> Commit.to_object()

      assert Object.valid?(xgit_commit_object)
      assert :ok = Object.check(xgit_commit_object)

      assert xgit_commit_object.id == ref_commit_id

      {output, 0} = System.cmd("git", ["write-tree", "--missing-ok"], cd: xgit)
      assert tree_content_id == String.trim(output)

      :ok = Repository.put_loose_object(repo, xgit_commit_object)

      assert_folders_are_equal(
        Path.join([ref, ".git", "objects"]),
        Path.join([xgit, ".git", "objects"])
      )
    end
  end
end
