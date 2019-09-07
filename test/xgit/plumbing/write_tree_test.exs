defmodule Xgit.Plumbing.WriteTreeTest do
  use Xgit.GitInitTestCase, async: true

  # alias Xgit.Core.DirCache
  # alias Xgit.Core.DirCache.Entry
  alias Xgit.GitInitTestCase
  alias Xgit.Plumbing.UpdateIndex.CacheInfo
  alias Xgit.Plumbing.WriteTree
  # alias Xgit.Repository
  alias Xgit.Repository.OnDisk

  import FolderDiff

  describe "to_tree_objects/2" do
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
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100644, "7919e8900c3af541535472aebd56d44222b7b3a3", 'hello.txt'}]
                   )
        end,
        missing_ok?: true
      )
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
                   CacheInfo.run(
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
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100644, "7fa62716fc68733db4c769fe678295cf4cf5b336", 'a/a/b'}]
                   )

          assert :ok =
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100644, "0f717230e297de82d0f8d761143dc1e1145c6bd5", 'a/b/c'}]
                   )

          assert :ok =
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100644, "ff287368514462578ba6406d366113953539cbf1", 'a/b/d'}]
                   )

          assert :ok =
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100644, "de588889c4d62aaf3ef3bd90be38fa239be2f5d1", 'a/c/x'}]
                   )

          assert :ok =
                   CacheInfo.run(
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
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100644, "7fa62716fc68733db4c769fe678295cf4cf5b336", 'a/a/b'}]
                   )

          assert :ok =
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100644, "0f717230e297de82d0f8d761143dc1e1145c6bd5", 'a/b/c'}]
                   )

          assert :ok =
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100644, "ff287368514462578ba6406d366113953539cbf1", 'a/b/d'}]
                   )

          assert :ok =
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100644, "de588889c4d62aaf3ef3bd90be38fa239be2f5d1", 'a/c/x'}]
                   )

          assert :ok =
                   CacheInfo.run(
                     xgit_repo,
                     [{0o100755, "7919e8900c3af541535472aebd56d44222b7b3a3", 'other.txt'}]
                   )
        end,
        missing_ok?: true,
        prefix: 'a/b'
      )
    end

    # test "missing_ok?: false happy path"

    # test "missing_ok? error"

    test "prefix doesn't exist" do
      {:ok, xgit: xgit} = GitInitTestCase.setup_git_repo()

      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      :ok =
        CacheInfo.run(
          repo,
          [{0o100644, "7fa62716fc68733db4c769fe678295cf4cf5b336", 'a/a/b'}]
        )

      :ok =
        CacheInfo.run(
          repo,
          [{0o100644, "0f717230e297de82d0f8d761143dc1e1145c6bd5", 'a/b/c'}]
        )

      :ok =
        CacheInfo.run(
          repo,
          [{0o100644, "ff287368514462578ba6406d366113953539cbf1", 'a/b/d'}]
        )

      :ok =
        CacheInfo.run(
          repo,
          [{0o100644, "de588889c4d62aaf3ef3bd90be38fa239be2f5d1", 'a/c/x'}]
        )

      :ok =
        CacheInfo.run(
          repo,
          [{0o100755, "7919e8900c3af541535472aebd56d44222b7b3a3", 'other.txt'}]
        )

      assert {:error, :prefix_not_found} =
               WriteTree.run(repo, missing_ok?: true, prefix: 'no/such/prefix')
    end

    # test "error: invalid dir cache" do
    #   assert {:error, :invalid_dir_cache} =
    #            DirCache.to_tree_objects(%DirCache{
    #              version: 2,
    #              entry_count: 3,
    #              entries: [
    #                Map.put(@valid_entry, :name, 'abc'),
    #                Map.put(@valid_entry, :name, 'abf'),
    #                Map.put(@valid_entry, :name, 'abe')
    #              ]
    #            })
    # end

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

      assert {:ok, xgit_object_id} = WriteTree.run(repo, opts)

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
