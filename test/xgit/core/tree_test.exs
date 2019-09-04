defmodule Xgit.Core.TreeTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Object
  alias Xgit.Core.Tree
  alias Xgit.Core.Tree.Entry
  alias Xgit.GitInitTestCase
  alias Xgit.Repository
  alias Xgit.Repository.OnDisk

  import FolderDiff

  @valid_entry %Entry{
    name: 'hello.txt',
    object_id: "7919e8900c3af541535472aebd56d44222b7b3a3",
    mode: 0o100644
  }

  @valid %Tree{
    entries: [@valid_entry]
  }

  describe "valid?/1" do
    test "happy path: valid entry" do
      assert Tree.valid?(@valid)
    end

    test "not a Tree struct" do
      refute Tree.valid?(%{})
      refute Tree.valid?("tree")
    end

    @invalid_mods [
      entries: [Map.put(@valid_entry, :name, "binary not allowed here")],
      entries: [Map.put(@valid_entry, :name, 'no/slashes')],
      entries: [42]
    ]

    test "invalid entries" do
      Enum.each(@invalid_mods, fn {key, value} ->
        invalid = Map.put(@valid, key, value)

        refute(
          Tree.valid?(invalid),
          "incorrectly accepted entry with :#{key} set to #{inspect(value)}"
        )
      end)
    end

    test "sorted (name)" do
      assert Tree.valid?(%Tree{
               entries: [
                 Map.put(@valid_entry, :name, 'abc'),
                 Map.put(@valid_entry, :name, 'abd'),
                 Map.put(@valid_entry, :name, 'abe')
               ]
             })
    end

    test "not sorted (name)" do
      refute Tree.valid?(%Tree{
               entries: [
                 Map.put(@valid_entry, :name, 'abc'),
                 Map.put(@valid_entry, :name, 'abf'),
                 Map.put(@valid_entry, :name, 'abe')
               ]
             })
    end
  end

  describe "to_object/1" do
    test "empty tree" do
      assert_same_output(
        fn _git_dir -> nil end,
        %Tree{entries: []}
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
        end,
        %Tree{
          entries: [
            %Entry{
              name: 'hello.txt',
              object_id: "7919e8900c3af541535472aebd56d44222b7b3a3",
              mode: 0o100644
            },
            %Entry{
              name: 'xyzzy.sh',
              object_id: "4a43a489f107e7ece679950f53567c648038449a",
              mode: 0o100755
            }
          ]
        }
      )
    end

    defp assert_same_output(git_ref_fn, xgit_tree) do
      {:ok, ref: ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      git_ref_fn.(ref)

      {output, 0} = System.cmd("git", ["write-tree", "--missing-ok"], cd: ref)
      content_id = String.trim(output)

      tree_object = Tree.to_object(xgit_tree)
      assert Object.valid?(tree_object)
      assert :ok = Object.check(tree_object)

      assert content_id == tree_object.id

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      :ok = Repository.put_loose_object(repo, tree_object)

      assert_folders_are_equal(
        Path.join([ref, ".git", "objects"]),
        Path.join([xgit, ".git", "objects"])
      )
    end
  end
end
