defmodule Xgit.Plumbing.LsFiles.StageTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Core.DirCache.Entry, as: DirCacheEntry
  alias Xgit.Plumbing.LsFiles.Stage, as: LsFilesStage
  alias Xgit.Repository
  alias Xgit.Repository.InMemory
  alias Xgit.Repository.OnDisk
  alias Xgit.Repository.WorkingTree

  describe "run/1" do
    test "happy path: no index file" do
      {:ok, repo} = InMemory.start_link()

      Temp.track!()
      path = Temp.mkdir!()

      {:ok, working_tree} = WorkingTree.start_link(repo, path)
      :ok = Repository.set_default_working_tree(repo, working_tree)

      assert {:ok, []} = LsFilesStage.run(repo)
    end

    test "happy path: can read from command-line git (empty index)", %{ref: ref} do
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
          cd: ref
        )

      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--remove",
            "hello.txt"
          ],
          cd: ref
        )

      {:ok, repo} = OnDisk.start_link(work_dir: ref)
      assert {:ok, []} = LsFilesStage.run(repo)
    end

    test "happy path: can read from command-line git (two small files)", %{ref: ref} do
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
          cd: ref
        )

      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--add",
            "--cacheinfo",
            "100644",
            "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
            "test_content.txt"
          ],
          cd: ref
        )

      {:ok, repo} = OnDisk.start_link(work_dir: ref)

      assert {:ok, entries} = LsFilesStage.run(repo)

      assert entries = [
               %DirCacheEntry{
                 assume_valid?: false,
                 ctime: 0,
                 ctime_ns: 0,
                 dev: 0,
                 extended?: false,
                 gid: 0,
                 ino: 0,
                 intent_to_add?: false,
                 mode: 0o100644,
                 mtime: 0,
                 mtime_ns: 0,
                 name: 'hello.txt',
                 object_id: "18832d35117ef2f013c4009f5b2128dfaeff354f",
                 size: 0,
                 skip_worktree?: false,
                 stage: 0,
                 uid: 0
               },
               %DirCacheEntry{
                 assume_valid?: false,
                 ctime: 0,
                 ctime_ns: 0,
                 dev: 0,
                 extended?: false,
                 gid: 0,
                 ino: 0,
                 intent_to_add?: false,
                 mode: 0o100644,
                 mtime: 0,
                 mtime_ns: 0,
                 name: 'test_content.txt',
                 object_id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
                 size: 0,
                 skip_worktree?: false,
                 stage: 0,
                 uid: 0
               }
             ]
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        LsFilesStage.run("xgit repo")
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)
      assert {:error, :invalid_repository} = LsFilesStage.run(not_repo)
    end

    test "error: no working tree" do
      {:ok, repo} = InMemory.start_link()
      assert {:error, :bare} = LsFilesStage.run(repo)
    end

    test "error: invalid index file", %{xgit: xgit} do
      git_dir = Path.join(xgit, ".git")
      File.mkdir_p!(git_dir)

      index_path = Path.join(git_dir, "index")
      File.write!(index_path, "DIRX")

      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert {:error, :invalid_format} = LsFilesStage.run(repo)
    end
  end
end
