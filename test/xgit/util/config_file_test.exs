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

    test "can parse subsection name" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
             bar
             [foo "zap"]
             bar=false
             n=3
             """) == [
               %ConfigEntry{name: "bar", section: "foo", subsection: "zip", value: nil},
               %ConfigEntry{name: "bar", section: "foo", subsection: "zap", value: "false"},
               %ConfigEntry{name: "n", section: "foo", subsection: "zap", value: "3"}
             ]
    end

    test "error: incomplete section name" do
      assert {%RuntimeError{message: "Illegal section header [foo"}, _} =
               raise_entries_from_config_file!(~s"""
               [foo
               bar
               """)
    end

    test "subsection name can have escaped double quote" do
      assert entries_from_config_file!(~s"""
             [foo "z\\\"ip"]
             bar
             [foo "zap"]
             bar=false
             n=3
             """) == [
               %ConfigEntry{name: "bar", section: "foo", subsection: ~S(z"ip), value: nil},
               %ConfigEntry{name: "bar", section: "foo", subsection: "zap", value: "false"},
               %ConfigEntry{name: "n", section: "foo", subsection: "zap", value: "3"}
             ]
    end

    test "subsection name can have escaped backslash" do
      assert entries_from_config_file!(~s"""
             [foo "z\\\\ip"]
             bar
             [foo "zap"]
             bar=false
             n=3
             """) == [
               %ConfigEntry{name: "bar", section: "foo", subsection: ~S(z\ip), value: nil},
               %ConfigEntry{name: "bar", section: "foo", subsection: "zap", value: "false"},
               %ConfigEntry{name: "n", section: "foo", subsection: "zap", value: "3"}
             ]
    end

    test "error: incomplete subsection name" do
      assert {%RuntimeError{message: "Illegal quoted string: Missing close quote"}, _} =
               raise_entries_from_config_file!(~s"""
               [foo "abc
               bar
               """)
    end

    test "variable name can contain numbers" do
      assert entries_from_config_file!(~s"""
             [foo "zip"] two5 = 25
             """) == [%ConfigEntry{name: "two5", section: "foo", subsection: "zip", value: "25"}]
    end

    test "variable name can contain hyphen" do
      assert entries_from_config_file!(~s"""
             [foo "zip"] two-five = 25
             """) == [
               %ConfigEntry{name: "two-five", section: "foo", subsection: "zip", value: "25"}
             ]
    end

    test "variable names are case-insensitive" do
      assert entries_from_config_file!(~s"""
             [foo "zip"] MumblE = 25
             """) == [
               %ConfigEntry{name: "mumble", section: "foo", subsection: "zip", value: "25"}
             ]
    end

    test "error: variable names may not contain other characters" do
      assert {%RuntimeError{
                message: ~s(Illegal variable declaration: [foo "zip"] mumble.more = 25)
              },
              _} =
               raise_entries_from_config_file!(~s"""
               [foo "zip"] mumble.more = 25
               """)
    end

    test "variable name + value can follow section header" do
      assert entries_from_config_file!(~s"""
             [foo "zip"] bar=42
             [foo "zap"]
             bar=false
             n=3
             """) == [
               %ConfigEntry{name: "bar", section: "foo", subsection: "zip", value: "42"},
               %ConfigEntry{name: "bar", section: "foo", subsection: "zap", value: "false"},
               %ConfigEntry{name: "n", section: "foo", subsection: "zap", value: "3"}
             ]
    end

    test "unquoted values strip leading whitespace" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
                bar =    42
             """) == [
               %ConfigEntry{name: "bar", section: "foo", subsection: "zip", value: "42"}
             ]
    end

    test "unquoted values strip trailing whitespace" do
      assert entries_from_config_file!("[foo \"zip\"] bar =42   ") == [
               %ConfigEntry{name: "bar", section: "foo", subsection: "zip", value: "42"}
             ]
    end

    test "internal whitespace is preserved verbatim" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
                bar = 42   and then\tsome
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "42   and then\tsome"
               }
             ]
    end

    test "comments starting with ; are ignored" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
                bar = 42
                ;blah = 45
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "42"
               }
             ]
    end

    test "comments starting with # are ignored" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
                bar = 42
             #[foo "bar"]
                blah = 45
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "42"
               },
               %ConfigEntry{
                 name: "blah",
                 section: "foo",
                 subsection: "zip",
                 value: "45"
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

  defp raise_entries_from_config_file!(config_file) do
    %{tmp_dir: tmp_dir} = TempDirTestCase.tmp_dir!()
    config_path = Path.join(tmp_dir, "config")

    File.write!(config_path, config_file)
    TestFileUtils.touch_back!(config_path)

    assert {:error, error} = ConfigFile.start_link(config_path)

    error
  end
end
