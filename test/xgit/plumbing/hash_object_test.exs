defmodule Xgit.Plumbing.HashObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.FileContentSource
  alias Xgit.GitInitTestCase
  alias Xgit.Plumbing.HashObject
  alias Xgit.Repository.OnDisk

  import FolderDiff

  describe "run/2" do
    test "happy path: deriving SHA hash with no repo" do
      # $ echo 'test content' | git hash-object --stdin
      # d670460b4b4aece5915caf5c68d12f560a9fe3e4

      assert {:ok, "d670460b4b4aece5915caf5c68d12f560a9fe3e4"} = HashObject.run("test content\n")
    end

    test "happy path: deriving SHA hash (large file on disk) with no repo" do
      Temp.track!()
      path = Temp.path!()

      content =
        1..1000
        |> Enum.map(fn _ -> "foobar" end)
        |> Enum.join()

      File.write!(path, content)

      {output, 0} = System.cmd("git", ["hash-object", path])
      expected_object_id = String.trim(output)

      assert {:ok, ^expected_object_id} =
               path
               |> FileContentSource.new()
               |> HashObject.run()
    end

    test "happy path: write to repo matches command-line git (small file)" do
      {:ok, ref: ref, xgit: xgit} = GitInitTestCase.setup_git_repo()
      # Only invoking GitInitTestCase manually here because other tests in this
      # module don't need it. Setting up a repo that we don't use in the other
      # tests would be wasteful.

      Temp.track!()
      path = Temp.path!()
      File.write!(path, "test content\n")

      {_output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: ref)

      assert :ok = OnDisk.create(xgit)
      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert {:ok, "d670460b4b4aece5915caf5c68d12f560a9fe3e4"} =
               HashObject.run("test content\n", repo: repo, write?: true)

      assert File.exists?(
               Path.join([xgit, ".git", "objects", "d6", "70460b4b4aece5915caf5c68d12f560a9fe3e4"])
             )

      assert_folders_are_equal(ref, xgit)
    end

    test "happy path: repo, but don't write, matches command-line git (small file)" do
      {:ok, ref: ref, xgit: xgit} = GitInitTestCase.setup_git_repo()
      # Only invoking GitInitTestCase manually here because other tests in this
      # module don't need it. Setting up a repo that we don't use in the other
      # tests would be wasteful.

      Temp.track!()
      path = Temp.path!()
      File.write!(path, "test content\n")

      {_output, 0} = System.cmd("git", ["hash-object", path], cd: ref)

      assert :ok = OnDisk.create(xgit)
      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert {:ok, "d670460b4b4aece5915caf5c68d12f560a9fe3e4"} =
               HashObject.run("test content\n", repo: repo, write?: false)

      refute File.exists?(
               Path.join([xgit, ".git", "objects", "d6", "70460b4b4aece5915caf5c68d12f560a9fe3e4"])
             )

      assert_folders_are_equal(ref, xgit)
    end

    test "happy path: validate content (content is valid)" do
      Temp.track!()
      path = Temp.path!()

      content = ~C"""
      tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
      author A. U. Thor <author@localhost> 1 +0000
      committer A. U. Thor <author@localhost> 1 +0000
      """

      File.write(path, content)

      {output, 0} = System.cmd("git", ["hash-object", "-t", "commit", path])
      expected_object_id = String.trim(output)

      assert {:ok, ^expected_object_id} =
               path
               |> FileContentSource.new()
               |> HashObject.run(type: :commit)
    end

    test "validate?: false skips validation" do
      Temp.track!()
      path = Temp.path!()

      content = ~C"""
      trie be9bfa841874ccc9f2ef7c48d0c76226f89b7189
      author A. U. Thor <author@localhost> 1 +0000
      committer A. U. Thor <author@localhost> 1 +0000
      """

      File.write(path, content)

      {output, 0} = System.cmd("git", ["hash-object", "--literally", "-t", "commit", path])
      expected_object_id = String.trim(output)

      assert {:ok, ^expected_object_id} =
               path
               |> FileContentSource.new()
               |> HashObject.run(type: :commit, validate?: false)
    end

    test "error: validate content (content is invalid)" do
      content = ~C"""
      trie be9bfa841874ccc9f2ef7c48d0c76226f89b7189
      author A. U. Thor <author@localhost> 1 +0000
      committer A. U. Thor <author@localhost> 1 +0000
      """

      assert {:error, "no tree header"} = HashObject.run(content, type: :commit)
    end

    test "error: content nil" do
      assert_raise FunctionClauseError, fn ->
        HashObject.run(nil)
      end
    end

    test "error: :type invalid" do
      assert_raise ArgumentError, "Xgit.Plumbing.HashObject.run/2: type :bogus is invalid", fn ->
        HashObject.run("test content\n", type: :bogus)
      end
    end

    test "error: :validate? invalid" do
      assert_raise ArgumentError,
                   ~s(Xgit.Plumbing.HashObject.run/2: validate? "yes" is invalid),
                   fn ->
                     HashObject.run("test content\n", validate?: "yes")
                   end
    end

    test "error: :repo invalid" do
      assert_raise ArgumentError,
                   ~s(Xgit.Plumbing.HashObject.run/2: repo "/path/to/repo" is invalid),
                   fn ->
                     HashObject.run("test content\n", repo: "/path/to/repo")
                   end
    end

    test "error: :write? invalid" do
      assert_raise ArgumentError,
                   ~s(Xgit.Plumbing.HashObject.run/2: write? "yes" is invalid),
                   fn ->
                     HashObject.run("test content\n", write?: "yes")
                   end
    end

    test "error: :write? without repo" do
      assert_raise ArgumentError,
                   ~s(Xgit.Plumbing.HashObject.run/2: write?: true requires a repo to be specified),
                   fn ->
                     HashObject.run("test content\n", write?: true)
                   end
    end
  end
end
