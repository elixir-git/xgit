defmodule Xgit.Util.FileUtilsTest do
  use ExUnit.Case, async: true

  import Xgit.Test.TempDirTestCase

  alias Xgit.Util.FileUtils

  describe "recursive_files!/1" do
    test "empty dir" do
      %{tmp_dir: tmp} = tmp_dir!()
      assert [] = FileUtils.recursive_files!(tmp)
    end

    test "dir doesn't exist" do
      %{tmp_dir: tmp} = tmp_dir!()
      foo_path = Path.join(tmp, "foo")
      assert [] = FileUtils.recursive_files!(foo_path)
    end

    test "one file" do
      %{tmp_dir: tmp} = tmp_dir!()
      foo_path = Path.join(tmp, "foo")
      File.write!(foo_path, "foo")
      assert [^foo_path] = FileUtils.recursive_files!(tmp)
    end

    test "one file, nested" do
      %{tmp_dir: tmp} = tmp_dir!()
      bar_dir_path = Path.join(tmp, "bar")
      File.mkdir_p!(bar_dir_path)
      foo_path = Path.join(bar_dir_path, "foo")
      File.write!(foo_path, "foo")
      assert [^foo_path] = FileUtils.recursive_files!(tmp)
    end

    test "three file" do
      %{tmp_dir: tmp} = tmp_dir!()

      foo_path = Path.join(tmp, "foo")
      File.write!(foo_path, "foo")

      bar_path = Path.join(tmp, "bar")
      File.write!(bar_path, "bar")

      blah_path = Path.join(tmp, "blah")
      File.write!(blah_path, "blah")

      assert [^bar_path, ^blah_path, ^foo_path] =
               tmp
               |> FileUtils.recursive_files!()
               |> Enum.sort()
    end
  end
end
