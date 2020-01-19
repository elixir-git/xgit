defmodule Xgit.Util.ConfigFileTest do
  use ExUnit.Case, async: true

  alias Xgit.ConfigEntry
  alias Xgit.Test.TempDirTestCase
  alias Xgit.Test.TestFileUtils
  alias Xgit.Util.ConfigFile

  describe "start_link/1 + get_entries/1" do
    test "error: parent dir does not exist" do
      %{tmp_dir: tmp_dir} = TempDirTestCase.tmp_dir!()
      path = Path.join(tmp_dir, "config/blah")

      assert_raise ArgumentError,
                   "Xgit.Util.ConfigFile.start_link/1: Parent of path #{path} must be an existing directory",
                   fn -> ConfigFile.start_link(path) end
    end

    test "file does not exist" do
      %{tmp_dir: tmp_dir} = TempDirTestCase.tmp_dir!()
      path = Path.join(tmp_dir, "config")
      refute File.exists?(path)

      assert {:ok, cf} = ConfigFile.start_link(path)
      assert is_pid(cf)

      assert {:ok, []} = ConfigFile.get_entries(cf)
    end

    test "simple file exists" do
      assert entries_from_config_file!(~s"""
             [core]
             \trepositoryformatversion = 0
             \tfilemode = true
             \tbare = false
             \tlogallrefupdates = true
             """) == [
               %ConfigEntry{
                 name: "repositoryformatversion",
                 section: "core",
                 subsection: nil,
                 value: "0"
               },
               %ConfigEntry{
                 name: "filemode",
                 section: "core",
                 subsection: nil,
                 value: "true"
               },
               %ConfigEntry{
                 name: "bare",
                 section: "core",
                 subsection: nil,
                 value: "false"
               },
               %ConfigEntry{
                 name: "logallrefupdates",
                 section: "core",
                 subsection: nil,
                 value: "true"
               }
             ]
    end

    test "joins lines with trailing backslash" do
      assert entries_from_config_file!(~s"""
             [core]
             \trepositoryformatversion = 0
             \tfilemode = true
             \tbare = false
             \tlogallrefupdates = true
             \twhatever = abc\\
             def
             """) == [
               %ConfigEntry{
                 name: "repositoryformatversion",
                 section: "core",
                 subsection: nil,
                 value: "0"
               },
               %ConfigEntry{
                 name: "filemode",
                 section: "core",
                 subsection: nil,
                 value: "true"
               },
               %ConfigEntry{
                 name: "bare",
                 section: "core",
                 subsection: nil,
                 value: "false"
               },
               %ConfigEntry{
                 name: "logallrefupdates",
                 section: "core",
                 subsection: nil,
                 value: "true"
               },
               %ConfigEntry{
                 name: "whatever",
                 section: "core",
                 subsection: nil,
                 value: "abc\ndef"
               }
             ]
    end
  end

  defp entries_from_config_file!(config_file) do
    %{tmp_dir: tmp_dir} = TempDirTestCase.tmp_dir!()
    config_path = Path.join(tmp_dir, "config")

    File.write!(config_path, config_file)
    TestFileUtils.touch_back!(config_path)

    assert {:ok, cf} = ConfigFile.start_link(config_path)
    assert {:ok, entries} = ConfigFile.get_entries(cf)

    entries
  end
end
