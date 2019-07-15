defmodule Xgit.Core.FileContentSourceTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.ContentSource
  alias Xgit.Core.FileContentSource

  describe "implementation for file that exists" do
    setup do
      Temp.track!()
      t = Temp.mkdir!()
      path = Path.join(t, "example")
      File.write!(path, "example")
      {:ok, path: path}
    end

    test "length/1", %{path: path} do
      fcs = FileContentSource.new(path)
      assert ContentSource.length(fcs) == 7
    end

    test "stream/1", %{path: path} do
      fcs = FileContentSource.new(path)

      assert %File.Stream{} = stream = ContentSource.stream(fcs)
      assert Enum.to_list(stream) == ['example']
    end
  end

  describe "implementation for file that doesn't exist" do
    setup do
      Temp.track!()
      t = Temp.mkdir!()
      path = Path.join(t, "example")
      {:ok, path: path}
    end

    test "length/1", %{path: path} do
      fcs = FileContentSource.new(path)

      assert_raise RuntimeError, "file not found", fn ->
        ContentSource.length(fcs)
      end
    end

    test "stream/1", %{path: path} do
      fcs = FileContentSource.new(path)

      assert_raise RuntimeError, "file not found", fn ->
        ContentSource.stream(fcs)
      end
    end
  end
end
