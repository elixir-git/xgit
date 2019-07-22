defmodule Xgit.Plumbing.HashObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.FileContentSource
  alias Xgit.Plumbing.HashObject

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
  end
end
