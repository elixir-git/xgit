defmodule Xgit.Repository.Plumbing.CatFileTreeTest do
  use Xgit.Test.OnDiskRepoTestCase, async: true

  alias Xgit.Repository.InMemory
  alias Xgit.Repository.InvalidRepositoryError
  alias Xgit.Repository.Plumbing
  alias Xgit.Tree

  describe "cat_file_tree/2" do
    defp write_git_tree_and_read_xgit_tree(xgit_repo, xgit_path) do
      {output, 0} = System.cmd("git", ["write-tree", "--missing-ok"], cd: xgit_path)
      tree_id = String.trim(output)

      assert {:ok, %Tree{} = tree} = Plumbing.cat_file_tree(xgit_repo, tree_id)
      tree
    end

    test "happy path: can read from command-line git (no files)", %{
      xgit_repo: xgit_repo,
      xgit_path: xgit_path
    } do
      assert %Tree{entries: []} = write_git_tree_and_read_xgit_tree(xgit_repo, xgit_path)
    end

    test "happy path: can read from command-line git (one file)", %{
      xgit_repo: xgit_repo,
      xgit_path: xgit_path
    } do
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
          cd: xgit_path
        )

      assert %Tree{
               entries: [
                 %Tree.Entry{
                   name: 'hello.txt',
                   mode: 0o100644,
                   object_id: "7919e8900c3af541535472aebd56d44222b7b3a3"
                 }
               ]
             } = write_git_tree_and_read_xgit_tree(xgit_repo, xgit_path)
    end

    test "tree with multiple entries", %{xgit_repo: xgit_repo, xgit_path: xgit_path} do
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
          cd: xgit_path
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
          cd: xgit_path
        )

      assert write_git_tree_and_read_xgit_tree(xgit_repo, xgit_path) == %Tree{
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
               Plumbing.cat_file_tree(repo, "6c22d81cc51c6518e4625a9fe26725af52403b4f")
    end

    test "error: invalid_object", %{xgit_repo: xgit_repo, xgit_path: xgit_path} do
      path = Path.join([xgit_path, ".git", "objects", "5c"])
      File.mkdir_p!(path)

      File.write!(
        Path.join(path, "b5d77be2d92c7368038dac67e648a69e0a654d"),
        <<120, 1, 75, 202, 201, 79, 170, 80, 48, 52, 50, 54, 97, 0, 0, 22, 54, 3, 2>>
      )

      assert {:error, :invalid_object} =
               Plumbing.cat_file_tree(xgit_repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
    end

    test "error: not_a_tree", %{xgit_repo: xgit_repo, xgit_path: xgit_path} do
      Temp.track!()
      path = Temp.path!()

      File.write!(path, "test content\n")

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: xgit_path)
      object_id = String.trim(output)

      assert {:error, :not_a_tree} = Plumbing.cat_file_tree(xgit_repo, object_id)
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        Plumbing.cat_file_tree("xgit repo", "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        Plumbing.cat_file_tree(not_repo, "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
      end
    end

    test "error: object_id invalid (not binary)" do
      {:ok, repo} = InMemory.start_link()

      assert_raise FunctionClauseError, fn ->
        Plumbing.cat_file_tree(repo, 0x18A4)
      end
    end

    test "error: object_id invalid (binary, but not valid object ID)" do
      {:ok, repo} = InMemory.start_link()

      assert {:error, :invalid_object_id} =
               Plumbing.cat_file_tree(repo, "some random ID that isn't valid")
    end
  end
end
