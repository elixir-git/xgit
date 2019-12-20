defmodule Xgit.Repository.Plumbing.WriteTreeTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.DirCache.Entry
  alias Xgit.GitInitTestCase
  alias Xgit.Repository.InvalidRepositoryError
  alias Xgit.Repository.OnDisk
  alias Xgit.Repository.Plumbing
  alias Xgit.Repository.Storage
  alias Xgit.Repository.WorkingTree

  import FolderDiff

  describe "run/2" do
    test "happy path: empty dir cache" do
      assert_same_output(fn _git_dir -> nil end, fn _xgit_repo -> nil end)
    end

    test "happy path: one root-level entry in dir cache" do
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
        end,
        fn xgit_repo ->
          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "7919e8900c3af541535472aebd56d44222b7b3a3", 'hello.txt'}]
                   )
        end,
        missing_ok?: true
      )
    end

    test "can ignore existing tree objects" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert :ok =
               Plumbing.update_index_cache_info(
                 repo,
                 [{0o100644, "7919e8900c3af541535472aebd56d44222b7b3a3", 'hello.txt'}]
               )

      assert {:ok, xgit_object_id} = Plumbing.write_tree(repo, missing_ok?: true)

      assert {:ok, ^xgit_object_id} = Plumbing.write_tree(repo, missing_ok?: true)
    end

    test "happy path: one blob nested one level" do
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
                "7fa62716fc68733db4c769fe678295cf4cf5b336",
                "a/b"
              ],
              cd: git_dir
            )
        end,
        fn xgit_repo ->
          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "7fa62716fc68733db4c769fe678295cf4cf5b336", 'a/b'}]
                   )
        end,
        missing_ok?: true
      )
    end

    test "happy path: deeply nested dir cache" do
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
        fn xgit_repo ->
          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "7fa62716fc68733db4c769fe678295cf4cf5b336", 'a/a/b'}]
                   )

          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "0f717230e297de82d0f8d761143dc1e1145c6bd5", 'a/b/c'}]
                   )

          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "ff287368514462578ba6406d366113953539cbf1", 'a/b/d'}]
                   )

          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "de588889c4d62aaf3ef3bd90be38fa239be2f5d1", 'a/c/x'}]
                   )

          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100755, "7919e8900c3af541535472aebd56d44222b7b3a3", 'other.txt'}]
                   )
        end,
        missing_ok?: true
      )
    end

    test "honors prefix" do
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
        fn xgit_repo ->
          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "7fa62716fc68733db4c769fe678295cf4cf5b336", 'a/a/b'}]
                   )

          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "0f717230e297de82d0f8d761143dc1e1145c6bd5", 'a/b/c'}]
                   )

          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "ff287368514462578ba6406d366113953539cbf1", 'a/b/d'}]
                   )

          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100644, "de588889c4d62aaf3ef3bd90be38fa239be2f5d1", 'a/c/x'}]
                   )

          assert :ok =
                   Plumbing.update_index_cache_info(
                     xgit_repo,
                     [{0o100755, "7919e8900c3af541535472aebd56d44222b7b3a3", 'other.txt'}]
                   )
        end,
        missing_ok?: true,
        prefix: 'a/b'
      )
    end

    test "missing_ok?: false happy path" do
      Temp.track!()
      path = Temp.path!()
      File.write!(path, "test content\n")

      assert_same_output(
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
        fn xgit_repo ->
          {:ok, object_id} = Plumbing.hash_object("test content\n", repo: xgit_repo, write?: true)
          :ok = Plumbing.update_index_cache_info(xgit_repo, [{0o100644, object_id, 'a/b'}])
        end
      )
    end

    test "missing_ok? error" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      :ok

      Plumbing.update_index_cache_info(
        repo,
        [{0o100644, "7919e8900c3af541535472aebd56d44222b7b3a3", 'hello.txt'}]
      )

      assert {:error, :objects_missing} = Plumbing.write_tree(repo)
    end

    test "prefix doesn't exist" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      :ok =
        Plumbing.update_index_cache_info(
          repo,
          [{0o100644, "7fa62716fc68733db4c769fe678295cf4cf5b336", 'a/a/b'}]
        )

      :ok =
        Plumbing.update_index_cache_info(
          repo,
          [{0o100644, "0f717230e297de82d0f8d761143dc1e1145c6bd5", 'a/b/c'}]
        )

      :ok =
        Plumbing.update_index_cache_info(
          repo,
          [{0o100644, "ff287368514462578ba6406d366113953539cbf1", 'a/b/d'}]
        )

      :ok =
        Plumbing.update_index_cache_info(
          repo,
          [{0o100644, "de588889c4d62aaf3ef3bd90be38fa239be2f5d1", 'a/c/x'}]
        )

      :ok =
        Plumbing.update_index_cache_info(
          repo,
          [{0o100755, "7919e8900c3af541535472aebd56d44222b7b3a3", 'other.txt'}]
        )

      assert {:error, :prefix_not_found} =
               Plumbing.write_tree(repo, missing_ok?: true, prefix: 'no/such/prefix')
    end

    test "error: invalid repo" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        Plumbing.write_tree(not_repo, missing_ok?: true)
      end
    end

    test "error: invalid dir cache" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)

      index_path = Path.join([xgit, ".git", "index"])
      File.write!(index_path, "not a valid index file")

      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert {:error, :invalid_format} = Plumbing.write_tree(repo, missing_ok?: true)
    end

    test "error: :missing_ok? invalid" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert_raise ArgumentError,
                   ~s(Xgit.Repository.Plumbing.write_tree/2: missing_ok? "sure" is invalid),
                   fn ->
                     Plumbing.write_tree(repo, missing_ok?: "sure")
                   end
    end

    @valid_entry %Entry{
      name: 'hello.txt',
      stage: 0,
      object_id: "7919e8900c3af541535472aebd56d44222b7b3a3",
      mode: 0o100644,
      size: 42,
      ctime: 1_565_612_933,
      ctime_ns: 0,
      mtime: 1_565_612_941,
      mtime_ns: 0,
      dev: 0,
      ino: 0,
      uid: 0,
      gid: 0,
      assume_valid?: true,
      extended?: false,
      skip_worktree?: false,
      intent_to_add?: false
    }

    test "error: incomplete merge" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      working_tree = Storage.default_working_tree(repo)

      :ok =
        WorkingTree.update_dir_cache(
          working_tree,
          [@valid_entry, Map.put(@valid_entry, :stage, 1)],
          []
        )

      assert {:error, :incomplete_merge} = Plumbing.write_tree(repo, missing_ok?: true)
    end

    test "error: can't write tree object" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      working_tree = Storage.default_working_tree(repo)
      :ok = WorkingTree.update_dir_cache(working_tree, [@valid_entry], [])

      objects_path = Path.join([xgit, ".git", "objects"])
      File.rm_rf!(objects_path)
      File.write!(objects_path, "not a directory")

      assert {:error, :cant_create_file} = Plumbing.write_tree(repo, missing_ok?: true)
    end

    test "error: :prefix invalid" do
      {:ok, ref: _ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert_raise ArgumentError,
                   ~s[Xgit.Repository.Plumbing.write_tree/2: prefix "a/b/c" is invalid (should be a charlist, not a String)],
                   fn ->
                     Plumbing.write_tree(repo, prefix: "a/b/c")
                   end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        Plumbing.write_tree(not_repo, missing_ok?: true)
      end
    end

    defp assert_same_output(git_ref_fn, xgit_fn, opts \\ []) do
      {:ok, ref: ref, xgit: xgit} = GitInitTestCase.setup_git_repo()

      missing_ok? = Keyword.get(opts, :missing_ok?, false)
      prefix = Keyword.get(opts, :prefix, [])

      git_ref_fn.(ref)

      git_opts =
        ["write-tree"]
        |> maybe_add_missing_ok?(missing_ok?)
        |> maybe_add_prefix(prefix)

      {output, 0} = System.cmd("git", git_opts, cd: ref)
      git_ref_object_id = String.trim(output)

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      xgit_fn.(repo)

      assert {:ok, xgit_object_id} = Plumbing.write_tree(repo, opts)

      assert_folders_are_equal(
        Path.join([ref, ".git", "objects"]),
        Path.join([xgit, ".git", "objects"])
      )

      assert git_ref_object_id == xgit_object_id
    end

    defp maybe_add_missing_ok?(git_opts, false), do: git_opts
    defp maybe_add_missing_ok?(git_opts, true), do: git_opts ++ ["--missing-ok"]

    defp maybe_add_prefix(git_opts, []), do: git_opts
    defp maybe_add_prefix(git_opts, prefix), do: git_opts ++ ["--prefix=#{prefix}"]
  end
end
