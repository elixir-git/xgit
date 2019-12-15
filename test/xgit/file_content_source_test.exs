defmodule Xgit.FileContentSourceTest do
  use ExUnit.Case, async: true

  alias Xgit.ContentSource
  alias Xgit.FileContentSource, as: FCS
  alias Xgit.Test.TempDirTestCase

  describe "implementation for file that exists" do
    setup do
      %{tmp_dir: t} = TempDirTestCase.tmp_dir!()

      path = Path.join(t, "example")
      File.write!(path, "example")

      fcs = FCS.new(path)

      {:ok, fcs: fcs}
    end

    test "length/1", %{fcs: fcs} do
      assert ContentSource.length(fcs) == 7
    end

    test "stream/1", %{fcs: fcs} do
      assert %File.Stream{} = stream = ContentSource.stream(fcs)
      assert Enum.to_list(stream) == ['example']
    end
  end

  describe "implementation for file that doesn't exist" do
    setup do
      %{tmp_dir: t} = TempDirTestCase.tmp_dir!()

      path = Path.join(t, "example")
      fcs = FCS.new(path)

      {:ok, fcs: fcs}
    end

    test "length/1", %{fcs: fcs} do
      assert_raise RuntimeError, "file not found", fn ->
        ContentSource.length(fcs)
      end
    end

    test "stream/1", %{fcs: fcs} do
      assert_raise RuntimeError, "file not found", fn ->
        ContentSource.stream(fcs)
      end
    end
  end
end
