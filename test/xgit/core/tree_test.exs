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

  describe "from_object/1" do
    setup do
      Temp.track!()
      repo = Temp.mkdir!()

      {_output, 0} = System.cmd("git", ["init"], cd: repo)
      objects_dir = Path.join([repo, ".git", "objects"])

      {:ok, xgit} = OnDisk.start_link(work_dir: repo)

      {:ok, repo: repo, objects_dir: objects_dir, xgit: xgit}
    end

    defp write_git_tree_and_read_xgit_tree_entries(repo, xgit) do
      {output, 0} = System.cmd("git", ["write-tree", "--missing-ok"], cd: repo)
      tree_id = String.trim(output)

      assert {:ok, %Object{} = object} = Repository.get_object(xgit, tree_id)
      assert {:ok, %Tree{entries: entries} = _tree} = Tree.from_object(object)

      entries
    end

    test "empty tree", %{repo: repo, xgit: xgit} do
      assert write_git_tree_and_read_xgit_tree_entries(repo, xgit) == []
    end

    test "tree with one entry", %{repo: repo, xgit: xgit} do
      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--add",
            "--cacheinfo",
            "100644",
            "18832d35117ef2f013c4009f5b2128dfaeff354f",
            "hello.txt"
          ],
          cd: repo
        )

      assert write_git_tree_and_read_xgit_tree_entries(repo, xgit) == [
               %Entry{
                 name: 'hello.txt',
                 object_id: "18832d35117ef2f013c4009f5b2128dfaeff354f",
                 mode: 0o100644
               }
             ]
    end

    test "tree with multiple entries", %{repo: repo, xgit: xgit} do
      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--add",
            "--cacheinfo",
            "100644",
            "18832d35117ef2f013c4009f5b2128dfaeff354f",
            "hello.txt"
          ],
          cd: repo
        )

      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--add",
            "--cacheinfo",
            "100755",
            "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
            "test_content.txt"
          ],
          cd: repo
        )

      assert write_git_tree_and_read_xgit_tree_entries(repo, xgit) == [
               %Entry{
                 name: 'hello.txt',
                 object_id: "18832d35117ef2f013c4009f5b2128dfaeff354f",
                 mode: 0o100644
               },
               %Entry{
                 name: 'test_content.txt',
                 object_id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
                 mode: 0o100755
               }
             ]
    end

    test "object is not a tree" do
      object = %Object{
        type: :blob,
        content: 'test content\n',
        size: 13,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
      }

      assert {:error, :not_a_tree} = Tree.from_object(object)
    end

    test "object is an invalid tree (ends after file mode)" do
      object = %Object{
        type: :tree,
        size: 42,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
        content: '100644'
      }

      assert {:error, :invalid_format} = Tree.from_object(object)
    end

    test "object is an invalid tree (invalid file mode)" do
      object = %Object{
        type: :tree,
        size: 42,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
        content: '100648 A 12345678901234567890'
      }

      assert {:error, :invalid_format} = Tree.from_object(object)
    end

    test "object is an invalid tree (invalid file mode, leading 0)" do
      object = %Object{
        type: :tree,
        size: 42,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
        content: '0100644 A 12345678901234567890'
      }

      assert {:error, :invalid_format} = Tree.from_object(object)
    end

    test "object is an invalid tree (not properly sorted)" do
      object = %Object{
        type: :tree,
        size: 42,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
        content:
          '100644 B' ++
            Enum.map(0..20, fn x -> x end) ++ '100644 A' ++ Enum.map(0..20, fn x -> x end)
      }

      assert {:error, :invalid_tree} = Tree.from_object(object)
    end

    test "object is a badly-formatted tree" do
      object = %Object{
        type: :tree,
        size: 42,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
        content: '100644 A' ++ Enum.map(0..20, fn _ -> 0 end)
      }

      assert {:error, :invalid_format} = Tree.from_object(object)
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
