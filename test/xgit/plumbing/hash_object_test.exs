defmodule Xgit.Plumbing.HashObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.FileContentSource
  alias Xgit.Plumbing.HashObject

  describe "run/2" do
    test "happy path: deriving SHA hash with no repo" do
      # $ echo 'test content' | git hash-object --stdin
      # d670460b4b4aece5915caf5c68d12f560a9fe3e4

      assert HashObject.run("test content\n") ==
               "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
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

      fcs = FileContentSource.new(path)
      assert HashObject.run(fcs) == expected_object_id
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
  end
end
