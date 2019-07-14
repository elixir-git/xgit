defmodule Xgit.Core.ObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Object

  describe "new/1" do
    test "happy path: content provided, type defaulted" do
      assert Object.new(content: "foo") == %Object{type: :blob, content: "foo"}
    end

    test "happy path: content and type both provided" do
      assert Object.new(content: "foo", type: :tag) == %Object{type: :tag, content: "foo"}
    end

    test "error: type invalid" do
      assert_raise(ArgumentError, "Xgit.Core.Object.new/1: type :bogus is invalid", fn ->
        Object.new(content: "foo", type: :bogus)
      end)
    end

    test "error: content missing" do
      assert_raise(ArgumentError, "Xgit.Core.Object.new/1: :content is missing", fn ->
        Object.new(type: :blob)
      end)
    end
  end
end
