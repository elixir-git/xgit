defmodule Xgit.ContentSourceTest do
  use ExUnit.Case, async: true

  alias Xgit.ContentSource

  describe "implementation for list" do
    test "length/1" do
      assert ContentSource.length('1234') == 4
    end

    test "stream/1" do
      assert ContentSource.stream('1234') == '1234'
    end
  end

  describe "implementation for string" do
    test "length/1" do
      assert ContentSource.length("1234") == 4
      assert ContentSource.length("1ü34") == 5
    end

    test "stream/1" do
      assert ContentSource.stream("1234") == '1234'
      assert ContentSource.stream("1ü34") == [49, 195, 188, 51, 52]
    end
  end
end
