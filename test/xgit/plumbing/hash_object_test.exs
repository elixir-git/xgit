defmodule Xgit.Plumbing.HashObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.Plumbing.HashObject

  describe "run/1" do
    test "happy path: deriving SHA hash with no repo" do
      # $ echo 'test content' | git hash-object --stdin
      # d670460b4b4aece5915caf5c68d12f560a9fe3e4

      assert HashObject.run(content: "test content\n") ==
               "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
    end

    test "error: :content missing" do
      assert_raise ArgumentError, "Xgit.Core.Object.new/1: :content is missing", fn ->
        HashObject.run([])
      end
    end

    test "error: :type invalid" do
      assert_raise ArgumentError, "Xgit.Core.Object.new/1: type :bogus is invalid", fn ->
        HashObject.run(content: "test content\n", type: :bogus)
      end
    end
  end
end
