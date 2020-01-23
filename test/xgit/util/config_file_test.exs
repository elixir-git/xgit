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

    test "ignores whitespace" do
      assert entries_from_config_file!(~s"""
             \t[core]
             repositoryformatversion=0
              filemode= true
                bare=   false
             \t logallrefupdates\t=\ttrue
             \twhatever = abc
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
                 value: "abc"
               }
             ]
    end

    test "section names are not case-sensitive" do
      assert entries_from_config_file!(~s"""
             [coRe]
             \trepositoryformatversion = 0
             """) == [
               %ConfigEntry{
                 name: "repositoryformatversion",
                 section: "core",
                 subsection: nil,
                 value: "0"
               }
             ]
    end

    test "only alphanumeric characters, -, and . are allowed in section names" do
      assert entries_from_config_file!(~s"""
             [core.foo]
             \trepositoryformatversion = 0
             """) == [
               %ConfigEntry{
                 name: "repositoryformatversion",
                 section: "core.foo",
                 subsection: nil,
                 value: "0"
               }
             ]

      assert entries_from_config_file!(~s"""
             [core-foo]
             \trepositoryformatversion = 0
             """) == [
               %ConfigEntry{
                 name: "repositoryformatversion",
                 section: "core-foo",
                 subsection: nil,
                 value: "0"
               }
             ]

      assert entries_from_config_file!(~s"""
             [core9]
             \trepositoryformatversion = 0
             """) == [
               %ConfigEntry{
                 name: "repositoryformatversion",
                 section: "core9",
                 subsection: nil,
                 value: "0"
               }
             ]

      assert entries_from_config_file!(~s"""
             [9core]
             \trepositoryformatversion = 0
             """) == [
               %ConfigEntry{
                 name: "repositoryformatversion",
                 section: "9core",
                 subsection: nil,
                 value: "0"
               }
             ]
    end

    test "accepts missing value" do
      assert entries_from_config_file!(~s"""
             [foo]
             bar
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: nil,
                 value: nil
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
