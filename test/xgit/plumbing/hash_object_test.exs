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
  end
end
