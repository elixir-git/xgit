defmodule Xgit.Repository.WorkingTree.ReadTreeTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry
  alias Xgit.GitInitTestCase
  alias Xgit.Plumbing.UpdateIndex.CacheInfo
  # alias Xgit.Plumbing.HashObject
  alias Xgit.Repository
  alias Xgit.Repository.OnDisk
  alias Xgit.Repository.WorkingTree

  # import ExUnit.CaptureLog

  describe "read_tree/2" do
    test "happy path: empty dir cache" do
      assert write_git_tree_and_read_back(
               fn git_dir ->
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
                     cd: git_dir
                   )

                 {_output, 0} =
                   System.cmd(
                     "git",
                     [
                       "update-index",
                       "--remove",
                       "hello.txt"
                     ],
                     cd: git_dir
                   )
               end,
               missing_ok?: true
             ) == DirCache.empty()
    end

    test "happy path: one root-level entry in dir cache" do
      assert write_git_tree_and_read_back(
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
               end,
               missing_ok?: true
             ) == %DirCache{
               version: 2,
               entry_count: 1,
               entries: [
                 %Entry{
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
                   object_id: "7919e8900c3af541535472aebd56d44222b7b3a3",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 }
               ]
             }
    end

    test "happy path: one blob nested one level" do
      assert write_git_tree_and_read_back(
               fn git_dir ->
                 {_output, 0} =
                   System.cmd(
                     "git",
                     [
                       "update-index",
                       "--add",
                       "--cacheinfo",
                       "100644",
                       "7fa62716fc68733db4c769fe678295cf4cf5b336",
                       "a/b"
                     ],
                     cd: git_dir
                   )
               end,
               missing_ok?: true
             ) == %DirCache{
               version: 2,
               entry_count: 1,
               entries: [
                 %Entry{
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
                   name: 'a/b',
                   object_id: "7fa62716fc68733db4c769fe678295cf4cf5b336",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 }
               ]
             }
    end

    test "happy path: deeply nested dir cache" do
      assert write_git_tree_and_read_back(
               fn git_dir ->
                 {_output, 0} =
                   System.cmd(
                     "git",
                     [
                       "update-index",
                       "--add",
                       "--cacheinfo",
                       "100644",
                       "7fa62716fc68733db4c769fe678295cf4cf5b336",
                       "a/a/b"
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
                       "100644",
                       "0f717230e297de82d0f8d761143dc1e1145c6bd5",
                       "a/b/c"
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
                       "100644",
                       "ff287368514462578ba6406d366113953539cbf1",
                       "a/b/d"
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
                       "100644",
                       "de588889c4d62aaf3ef3bd90be38fa239be2f5d1",
                       "a/c/x"
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
                       "7919e8900c3af541535472aebd56d44222b7b3a3",
                       "other.txt"
                     ],
                     cd: git_dir
                   )
               end,
               missing_ok?: true
             ) == %DirCache{
               version: 2,
               entry_count: 5,
               entries: [
                 %Entry{
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
                   name: 'a/a/b',
                   object_id: "7fa62716fc68733db4c769fe678295cf4cf5b336",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 },
                 %Entry{
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
                   name: 'a/b/c',
                   object_id: "0f717230e297de82d0f8d761143dc1e1145c6bd5",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 },
                 %Entry{
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
                   name: 'a/b/d',
                   object_id: "ff287368514462578ba6406d366113953539cbf1",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 },
                 %Entry{
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
                   name: 'a/c/x',
                   object_id: "de588889c4d62aaf3ef3bd90be38fa239be2f5d1",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 },
                 %Entry{
                   assume_valid?: false,
                   ctime: 0,
                   ctime_ns: 0,
                   dev: 0,
                   extended?: false,
                   gid: 0,
                   ino: 0,
                   intent_to_add?: false,
                   mode: 0o100755,
                   mtime: 0,
                   mtime_ns: 0,
                   name: 'other.txt',
                   object_id: "7919e8900c3af541535472aebd56d44222b7b3a3",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 }
               ]
             }
    end

    test "missing_ok?: false happy path" do
      Temp.track!()
      path = Temp.path!()
      File.write!(path, "test content\n")

      assert write_git_tree_and_read_back(
               fn git_dir ->
                 {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: git_dir)
                 object_id = String.trim(output)

                 {_output, 0} =
                   System.cmd(
                     "git",
                     ["update-index", "--add", "--cacheinfo", "100644", object_id, "a/b"],
                     cd: git_dir
                   )
               end,
               missing_ok?: false
             ) == %DirCache{
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
                   mode: 33188,
                   mtime: 0,
                   mtime_ns: 0,
                   name: 'a/b',
                   object_id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 }
               ],
               entry_count: 1,
               version: 2
             }
    end

    test "missing_ok? error" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      :ok

      CacheInfo.run(
        repo,
        [{0o100644, "7919e8900c3af541535472aebd56d44222b7b3a3", 'hello.txt'}]
      )

      {output, 0} = System.cmd("git", ["write-tree", "--missing-ok"], cd: xgit)
      tree_object_id = String.trim(output)

      working_tree = Repository.default_working_tree(repo)

      assert {:error, :objects_missing} = WorkingTree.read_tree(working_tree, tree_object_id)
    end

    test "error: :missing_ok? invalid" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      working_tree = Repository.default_working_tree(repo)

      assert_raise ArgumentError,
                   ~s(Xgit.Repository.WorkingTree.read_tree/3: missing_ok? "sure" is invalid),
                   fn ->
                     WorkingTree.read_tree(
                       working_tree,
                       "7919e8900c3af541535472aebd56d44222b7b3a3",
                       missing_ok?: "sure"
                     )
                   end
    end

    # test "error: can't write tree object" do
    #   {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

    #   :ok = OnDisk.create(xgit)
    #   {:ok, repo} = OnDisk.start_link(work_dir: xgit)

    #   working_tree = Repository.default_working_tree(repo)
    #   :ok = WorkingTree.update_dir_cache(working_tree, [@valid_entry], [])

    #   objects_path = Path.join([xgit, ".git", "objects"])
    #   File.rm_rf!(objects_path)
    #   File.write!(objects_path, "not a directory")

    #   assert {:error, :cant_create_file} = WorkingTree.read_tree(working_tree, missing_ok?: true)
    # end

    defp write_git_tree_and_read_back(git_ref_fn, opts) do
      {:ok, ref: ref, xgit: _xgit} = GitInitTestCase.setup_git_repo()

      # ref = "/Users/scouten/Desktop/foo"
      # File.rm_rf!(ref)
      # File.mkdir_p!(ref)

      # {_output, 0} = System.cmd("git", ["init"], cd: ref)

      git_ref_fn.(ref)

      {output, 0} = System.cmd("git", ["write-tree", "--missing-ok"], cd: ref)
      tree_object_id = String.trim(output)

      # We want the *tree* to be present, but the dir cache should be empty.
      # Otherwise, the subsequent call to `WorkingTree.dir_cache/1` could mask
      # any failure in `WorkingTree.read_tree/2`.
      {_output, 0} = System.cmd("git", ["read-tree", "--empty"], cd: ref)

      {:ok, repo} = OnDisk.start_link(work_dir: ref)

      working_tree = Repository.default_working_tree(repo)

      assert :ok = WorkingTree.read_tree(working_tree, tree_object_id, opts)
      assert {:ok, dir_cache} = WorkingTree.dir_cache(working_tree)

      dir_cache
    end
  end
end
