defmodule Xgit.Plumbing.CatFile.TreeTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Core.Tree
  alias Xgit.Plumbing.CatFile.Tree, as: CatFileTree
  alias Xgit.Repository.InMemory
  alias Xgit.Repository.OnDisk
  alias Xgit.Test.TempDirTestCase

  describe "run/2" do
    setup do
      %{tmp_dir: xgit_path} = TempDirTestCase.tmp_dir!()

      {_output, 0} = System.cmd("git", ["init"], cd: xgit_path)
      objects_dir = Path.join([xgit_path, ".git", "objects"])

      {:ok, xgit} = OnDisk.start_link(work_dir: xgit_path)

      {:ok, repo: xgit_path, objects_dir: objects_dir, xgit: xgit}
    end

    defp write_git_tree_and_read_xgit_tree(repo, xgit) do
      {output, 0} = System.cmd("git", ["write-tree", "--missing-ok"], cd: repo)
      tree_id = String.trim(output)

      assert {:ok, %Tree{} = tree} = CatFileTree.run(xgit, tree_id)
      tree
    end

    test "happy path: can read from command-line git (no files)", %{repo: repo, xgit: xgit} do
      assert %Tree{entries: []} = write_git_tree_and_read_xgit_tree(repo, xgit)
    end

    test "happy path: can read from command-line git (one file)", %{repo: repo, xgit: xgit} do
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
          cd: repo
        )

      assert %Tree{
               entries: [
                 %Tree.Entry{
                   name: 'hello.txt',
                   mode: 0o100644,
                   object_id: "7919e8900c3af541535472aebd56d44222b7b3a3"
                 }
               ]
             } = write_git_tree_and_read_xgit_tree(repo, xgit)
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

      assert write_git_tree_and_read_xgit_tree(repo, xgit) == %Tree{
               entries: [
                 %Tree.Entry{
                   name: 'hello.txt',
                   object_id: "18832d35117ef2f013c4009f5b2128dfaeff354f",
                   mode: 0o100644
                 },
                 %Tree.Entry{
                   name: 'test_content.txt',
                   object_id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
                   mode: 0o100755
                 }
               ]
             }
    end

    test "error: not_found" do
      {:ok, repo} = InMemory.start_link()

      assert {:error, :not_found} =
               CatFileTree.run(repo, "6c22d81cc51c6518e4625a9fe26725af52403b4f")
    end

    test "error: invalid_object", %{repo: repo, xgit: xgit} do
      path = Path.join([repo, ".git", "objects", "5c"])
      File.mkdir_p!(path)

      File.write!(
        Path.join(path, "b5d77be2d92c7368038dac67e648a69e0a654d"),
        <<120, 1, 75, 202, 201, 79, 170, 80, 48, 52, 50, 54, 97, 0, 0, 22, 54, 3, 2>>
      )

      assert {:error, :invalid_object} =
               CatFileTree.run(xgit, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
    end

    test "error: not_a_tree", %{repo: repo, xgit: xgit} do
      Temp.track!()
      path = Temp.path!()

      File.write!(path, "test content\n")

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: repo)
      object_id = String.trim(output)

      assert {:error, :not_a_tree} = CatFileTree.run(xgit, object_id)
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        CatFileTree.run("xgit repo", "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert {:error, :invalid_repository} =
               CatFileTree.run(not_repo, "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
    end

    test "error: object_id invalid (not binary)" do
      {:ok, repo} = InMemory.start_link()

      assert_raise FunctionClauseError, fn ->
        CatFileTree.run(repo, 0x18A4)
      end
    end

    test "error: object_id invalid (binary, but not valid object ID)" do
      {:ok, repo} = InMemory.start_link()

      assert {:error, :invalid_object_id} =
               CatFileTree.run(repo, "some random ID that isn't valid")
    end
  end
end
