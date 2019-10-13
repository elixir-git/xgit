defmodule Xgit.Util.ParseHeaderTest do
  use ExUnit.Case, async: true

  alias Xgit.Util.ParseHeader

  describe "next_header/1" do
    test "happy path" do
      assert {'tree', 'abcdef', 'what remains\n'} =
               ParseHeader.next_header(~C"""
               tree abcdef
               what remains
               """)
    end

    test "happy path (last line)" do
      assert {'tree', 'abcdef', []} =
               ParseHeader.next_header(~C"""
               tree abcdef
               """)
    end

    test "happy path (no trailing LF)" do
      assert {'tree', 'abcdef', []} = ParseHeader.next_header('tree abcdef')
    end

    test "no header value" do
      assert :no_header_found = ParseHeader.next_header('abc')
    end

    test "no header value (trailing LF)" do
      assert :no_header_found = ParseHeader.next_header('abc\n')
    end

    test "empty charlist" do
      assert :no_header_found = ParseHeader.next_header([])
    end
  end
end
