defmodule Xgit.Repository.WorkingTree.DirCacheTest do
  use ExUnit.Case, async: true

  alias Xgit.DirCache
  alias Xgit.Repository.InMemory
  alias Xgit.Repository.OnDisk
  alias Xgit.Repository.Storage
  alias Xgit.Repository.WorkingTree
  alias Xgit.Test.OnDiskRepoTestCase

  describe "dir_cache/1" do
    test "happy path: no index file" do
      Temp.track!()
      path = Temp.path!()

      {:ok, repo} = InMemory.start_link()
      {:ok, working_tree} = WorkingTree.start_link(repo, path)

      assert {:ok, %DirCache{entry_count: 0} = dir_cache} = WorkingTree.dir_cache(working_tree)
      assert DirCache.valid?(dir_cache)
    end

    test "happy path: can read from command-line git (empty index)" do
      %{xgit_path: ref, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

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

      working_tree = Storage.default_working_tree(repo)

      assert {:ok, %DirCache{entry_count: 0} = dir_cache} = WorkingTree.dir_cache(working_tree)
      assert DirCache.valid?(dir_cache)
    end

    test "happy path: can read from command-line git (two small files)" do
      %{xgit_path: ref, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

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

      working_tree = Storage.default_working_tree(repo)

      assert {:ok, %DirCache{} = dir_cache} = WorkingTree.dir_cache(working_tree)
      assert DirCache.valid?(dir_cache)

      assert dir_cache = %DirCache{
               entries: [
                 %DirCache.Entry{
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
                 %DirCache.Entry{
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
               ],
               entry_count: 2,
               version: 2
             }
    end

    test "error: file doesn't start with DIRC signature" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()
      assert {:error, :invalid_format} = parse_iodata_as_index_file(xgit, 'DIRX')
    end

    test "error: unsupported version" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

      assert {:error, :unsupported_version} =
               parse_iodata_as_index_file(xgit, [
                 'DIRC',
                 0,
                 0,
                 0,
                 1,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0
               ])
    end

    test "error: 'index' is a directory" do
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      index_path = Path.join([xgit, ".git", "index"])
      File.mkdir_p!(index_path)
      # ^ WRONG! Should be a file, not a directory.

      working_tree = Storage.default_working_tree(repo)

      assert {:error, :eisdir} = WorkingTree.dir_cache(working_tree)
    end
  end

  defp parse_iodata_as_index_file(xgit, iodata) do
    git_dir = Path.join(xgit, ".git")
    File.mkdir_p!(git_dir)

    index_path = Path.join(git_dir, "index")
    File.write!(index_path, iodata)

    {:ok, repo} = OnDisk.start_link(work_dir: xgit)
    working_tree = Storage.default_working_tree(repo)

    WorkingTree.dir_cache(working_tree)
  end
end
