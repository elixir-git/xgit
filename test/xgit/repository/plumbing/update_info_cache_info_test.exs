defmodule Xgit.Repository.Plumbing.UpdateInfoCacheInfoTest do
  use ExUnit.Case, async: true

  alias Xgit.Repository.InMemory
  alias Xgit.Repository.InvalidRepositoryError
  alias Xgit.Repository.Plumbing
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  describe "run/2" do
    test "happy path: write to repo matches command-line git (one file)" do
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

      assert :ok =
               Plumbing.update_index_cache_info(
                 repo,
                 [{0o100644, "18832d35117ef2f013c4009f5b2128dfaeff354f", 'hello.txt'}]
               )

      assert_folders_are_equal(ref, xgit)
    end

    test "happy path: git ls-files can read output from UpdateIndex.CacheInfo (one file)" do
      %{xgit_path: ref, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert :ok =
               Plumbing.update_index_cache_info(
                 repo,
                 [{0o100644, "18832d35117ef2f013c4009f5b2128dfaeff354f", 'hello.txt'}]
               )

      assert {output, 0} = System.cmd("git", ["ls-files", "--stage"], cd: ref)
      assert output == "100644 18832d35117ef2f013c4009f5b2128dfaeff354f 0	hello.txt\n"
    end

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

      assert :ok = Plumbing.update_index_cache_info(repo, [])

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

      assert :ok =
               Plumbing.update_index_cache_info(
                 repo,
                 [
                   {0o100644, "18832d35117ef2f013c4009f5b2128dfaeff354f", 'hello.txt'},
                   {0o100644, "d670460b4b4aece5915caf5c68d12f560a9fe3e4", 'test_content.txt'}
                 ]
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

      assert :ok = Plumbing.update_index_cache_info(repo, [], ['test_content.txt'])

      assert_folders_are_equal(ref, xgit)
    end

    test "error: file doesn't start with DIRC signature" do
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      git_dir = Path.join(xgit, '.git')
      File.mkdir_p!(git_dir)

      index = Path.join(git_dir, 'index')
      File.write!(index, 'DIRX12345678901234567890')

      assert {:error, :invalid_format} =
               Plumbing.update_index_cache_info(repo, [], ['test_content.txt'])
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        Plumbing.update_index_cache_info("xgit repo", [])
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        Plumbing.update_index_cache_info(not_repo, [])
      end
    end

    test "error: no working tree" do
      {:ok, repo} = InMemory.start_link()
      assert {:error, :bare} = Plumbing.update_index_cache_info(repo, [])
    end

    test "error: invalid index file" do
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      git_dir = Path.join(xgit, ".git")
      File.mkdir_p!(git_dir)

      index_path = Path.join(git_dir, "index")
      File.write!(index_path, "DIRX")

      assert {:error, :invalid_format} = Plumbing.update_index_cache_info(repo, [])
    end

    test "error: invalid entries (add)" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :invalid_entry} =
               Plumbing.update_index_cache_info(repo, [
                 {0o100644, "18832d35117ef2f013c4009f5b2128dfaeff354f", "hello.txt"}
               ])

      # Used a string for path here; path should be binary.
    end

    test "error: invalid entries (remove)" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :invalid_entry} =
               Plumbing.update_index_cache_info(repo, [], ["should be a charlist"])
    end
  end
end
