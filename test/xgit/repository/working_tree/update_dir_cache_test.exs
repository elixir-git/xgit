defmodule Xgit.Repository.WorkingTree.UpdateDirCacheTest do
  use ExUnit.Case, async: true

  alias Xgit.DirCache
  alias Xgit.Repository.Storage
  alias Xgit.Repository.WorkingTree
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  describe "update_dir_cache/1" do
    test "happy path: can generate correct empty index file" do
      %{xgit_path: ref} = OnDiskRepoTestCase.repo!()
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      # An initialized git repo doesn't have an index file at all.
      # Adding and removing a file generates an empty index file.

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

      assert :ok = WorkingTree.update_dir_cache(working_tree, [], [])

      assert_folders_are_equal(ref, xgit)
    end

    test "can write an index file with entries that matches command-line git" do
      %{xgit_path: ref} = OnDiskRepoTestCase.repo!()
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

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

      assert :ok =
               WorkingTree.update_dir_cache(
                 working_tree,
                 [
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
                 []
               )

      assert_folders_are_equal(ref, xgit)
    end

    test "can remove entries from index file" do
      %{xgit_path: ref} = OnDiskRepoTestCase.repo!()
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

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

      # For variety, let's use command-line git to write the first index file
      # and then update it with Xgit.

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
          cd: xgit
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
          cd: xgit
        )

      working_tree = Storage.default_working_tree(repo)

      assert :ok =
               assert(
                 :ok =
                   WorkingTree.update_dir_cache(
                     working_tree,
                     [],
                     [{'test_content.txt', 0}]
                   )
               )

      assert_folders_are_equal(ref, xgit)
    end

    test "error: file doesn't start with DIRC signature" do
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      git_dir = Path.join(xgit, '.git')
      File.mkdir_p!(git_dir)

      index = Path.join(git_dir, 'index')
      File.write!(index, 'DIRX12345678901234567890')

      working_tree = Storage.default_working_tree(repo)

      assert {:error, :invalid_format} =
               WorkingTree.update_dir_cache(
                 working_tree,
                 [],
                 [{'test_content.txt', 0}]
               )
    end
  end
end
