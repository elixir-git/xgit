defmodule Xgit.Util.ConfigFileTest do
  use ExUnit.Case, async: true

  alias Xgit.ConfigEntry
  alias Xgit.Test.OnDiskRepoTestCase
  alias Xgit.Test.TempDirTestCase
  alias Xgit.Test.TestFileUtils
  alias Xgit.Util.ConfigFile

  import ExUnit.CaptureLog
  import FolderDiff

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

    test "understands multi-valued variables" do
      assert entries_from_config_file!(~s"""
             [core]
             \trepositoryformatversion = 0
             \tfilemode = true
             \tbare = false
             \tgitproxy = command1
             \tgitproxy = command2
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
                 name: "gitproxy",
                 section: "core",
                 subsection: nil,
                 value: "command1"
               },
               %ConfigEntry{
                 name: "gitproxy",
                 section: "core",
                 subsection: nil,
                 value: "command2"
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

    test "error: section name must precede a variable declaration" do
      assert {%ArgumentError{
                message:
                  ~s(Invalid config file: Assigning variable mumble without a section header)
              },
              _} =
               raise_entries_from_config_file!(~s"""
               mumble = 25
               """)
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
      assert {%ArgumentError{message: "Illegal section header [foo"}, _} =
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
      assert {%ArgumentError{message: "Illegal quoted string: Missing close quote"}, _} =
               raise_entries_from_config_file!(~s"""
               [foo "abc
               bar
               """)
    end

    test "error: subsection name can not contain new line" do
      assert {%ArgumentError{message: "Illegal quoted string: Can not span a new line"}, _} =
               raise_entries_from_config_file!(~S"""
               [foo "abc\
               bar"]
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
      assert {%ArgumentError{
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

    test "values may be quoted" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
                bar = "42"
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "42"
               }
             ]
    end

    test "error: quoted values may not span lines" do
      assert {%ArgumentError{
                message: "Incomplete quoted string"
              },
              _} =
               raise_entries_from_config_file!(~s"""
               [foo "zip"]
                  bar = "42
                  and then 43"
               """)
    end

    test "values may be partially quoted" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
                bar = 41, "42", and then 43
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "41, 42, and then 43"
               }
             ]
    end

    test "quoted values retain leading whitespace" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
                bar =    "  42"
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "  42"
               }
             ]
    end

    test "quoted values retain trailing whitespace" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
                bar = "42   "   ; random comment
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "42   "
               }
             ]
    end

    test "quoted values can contain escaped backslash" do
      assert entries_from_config_file!(~S"""
             [foo "zip"]
                bar = "4\\2"
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "4\\2"
               }
             ]
    end

    test "quoted values can contain escaped quote" do
      assert entries_from_config_file!(~S"""
             [foo "zip"]
                bar = "4\"2"
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "4\"2"
               }
             ]
    end

    test "quoted values can contain \\n escape (newline)" do
      assert entries_from_config_file!(~S"""
             [foo "zip"]
                bar = "4\n2"
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "4\n2"
               }
             ]
    end

    test "quoted values can contain \\t escape (newline)" do
      assert entries_from_config_file!(~S"""
             [foo "zip"]
                bar = "4\t2"
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "4\t2"
               }
             ]
    end

    test "quoted values can contain \\b escape (backspace)" do
      assert entries_from_config_file!(~S"""
             [foo "zip"]
                bar = "4\b2"
             """) == [
               %ConfigEntry{
                 name: "bar",
                 section: "foo",
                 subsection: "zip",
                 value: "4\b2"
               }
             ]
    end

    test "error: quoted values cannot contain any other backslash sequence" do
      assert {%ArgumentError{
                message: "Invalid config file: Unknown escape sequence \\x"
              },
              _} =
               raise_entries_from_config_file!(~S"""
               [foo "zip"]
                  bar = "4\x02"
               """)
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

    test "comments starting with # are ignored (1)" do
      assert entries_from_config_file!(~s"""
             [foo "zip"]
                bar = 42
                blah = 45 # not 46
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

    test "comments starting with # are ignored (2)" do
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

    test "re-reads file when updated" do
      %{tmp_dir: tmp_dir} = TempDirTestCase.tmp_dir!()
      config_path = Path.join(tmp_dir, "config")

      File.write!(config_path, ~s([foo "zip"] bar = 42))
      TestFileUtils.touch_back!(config_path)

      assert {:ok, cf} = ConfigFile.start_link(config_path)

      assert {:ok,
              [
                %ConfigEntry{
                  name: "bar",
                  section: "foo",
                  subsection: "zip",
                  value: "42"
                }
              ]} = ConfigFile.get_entries(cf)

      File.write!(config_path, ~s([foo "zip"] bar = 44))

      assert {:ok,
              [
                %ConfigEntry{
                  name: "bar",
                  section: "foo",
                  subsection: "zip",
                  value: "44"
                }
              ]} = ConfigFile.get_entries(cf)
    end

    test "filter on section + name" do
      assert entries_from_config_file!(
               ~s"""
               [core]
               \trepositoryformatversion = 0
               \tfilemode = true
               \tbare = false
               \tlogallrefupdates = true
               [other]
               \tfilemode = wrong
               """,
               section: "core",
               name: "filemode"
             ) == [
               %ConfigEntry{
                 name: "filemode",
                 section: "core",
                 subsection: nil,
                 value: "true"
               }
             ]
    end

    test "filter on section + subsection + name" do
      assert entries_from_config_file!(
               ~s"""
               [foo "zip"]
               bar
               [foo "zap"]
               bar=false
               n=3
               [other "zip"]
               this=is wrong
               """,
               section: "foo",
               subsection: "zip",
               name: "bar"
             ) == [
               %ConfigEntry{name: "bar", section: "foo", subsection: "zip", value: nil}
             ]
    end

    test "filter on section + name won't match subsection" do
      assert entries_from_config_file!(
               ~s"""
               [foo "zip"]
               bar
               [foo "zap"]
               bar=false
               n=3
               [foo]
               bar=only this
               bah=but not this
               """,
               section: "foo",
               name: "bar"
             ) == [
               %ConfigEntry{name: "bar", section: "foo", subsection: nil, value: "only this"}
             ]
    end

    test "filter on section only" do
      assert entries_from_config_file!(
               ~s"""
               [core]
               \trepositoryformatversion = 0
               \tfilemode = true
               \tbare = false
               \tlogallrefupdates = true
               [other]
               \tmumble = true
               """,
               section: "core"
             ) == [
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

    test "filter on section + subsection" do
      assert entries_from_config_file!(
               ~s"""
               [foo "zip"]
               bar
               [foo "zap"]
               bar=false
               n=3
               """,
               section: "foo",
               subsection: "zap"
             ) == [
               %ConfigEntry{name: "bar", section: "foo", subsection: "zap", value: "false"},
               %ConfigEntry{name: "n", section: "foo", subsection: "zap", value: "3"}
             ]
    end

    test "filter on section alone won't match subsection" do
      assert entries_from_config_file!(
               ~s"""
               [foo "zip"]
               bar
               [foo "zap"]
               bar=false
               n=3
               [foo]
               only=this
               """,
               section: "foo"
             ) == [
               %ConfigEntry{name: "only", section: "foo", subsection: nil, value: "this"}
             ]
    end
  end

  defp entries_from_config_file!(config_file, opts \\ []) do
    %{tmp_dir: tmp_dir} = TempDirTestCase.tmp_dir!()
    config_path = Path.join(tmp_dir, "config")

    File.write!(config_path, config_file)
    TestFileUtils.touch_back!(config_path)

    assert {:ok, cf} = ConfigFile.start_link(config_path)
    assert {:ok, entries} = ConfigFile.get_entries(cf, opts)

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

  @example_config ~s"""
  #
  # This is the config file, and
  # a '#' or ';' character indicates
  # a comment
  #

  ; core variables
  [core]
    ; Don't trust file modes
    filemode = false

  ; Our diff algorithm
  [diff]
    external = /usr/local/bin/diff-wrapper
    renames = true

  ; Proxy settings
  [core]
    gitproxy=proxy-command for kernel.org
    gitproxy=default-proxy ; for all the rest

  ; HTTP
  [http]
    sslVerify
  [http "https://weak.example.com"]
    sslVerify = false
    cookieFile = /tmp/cookie.txt
  """

  describe "add_entries/3" do
    test "basic case with default options" do
      assert_configs_are_equal(
        initial_config: @example_config,
        git_add_fn: fn path ->
          assert {"", 0} = System.cmd("git", ["config", "core.filemode", "true"], cd: path)
        end,
        xgit_add_fn: fn config_file ->
          assert :ok =
                   ConfigFile.add_entries(
                     config_file,
                     [
                       %ConfigEntry{
                         section: "core",
                         subsection: nil,
                         name: "filemode",
                         value: "true"
                       }
                     ]
                   )
        end
      )
    end

    test "add multiple entries in different sections" do
      assert_configs_are_equal(
        initial_config: @example_config,
        git_add_fn: fn path ->
          assert {"", 0} = System.cmd("git", ["config", "core.filemode", "true"], cd: path)
          assert {"", 0} = System.cmd("git", ["config", "other.mumble", "42"], cd: path)
        end,
        xgit_add_fn: fn config_file ->
          assert :ok =
                   ConfigFile.add_entries(
                     config_file,
                     [
                       %ConfigEntry{
                         section: "core",
                         subsection: nil,
                         name: "filemode",
                         value: "true"
                       },
                       %ConfigEntry{
                         section: "other",
                         subsection: nil,
                         name: "mumble",
                         value: "42"
                       }
                     ]
                   )
        end
      )
    end

    test "creating a new subsection" do
      assert_configs_are_equal(
        initial_config: @example_config,
        git_add_fn: fn path ->
          assert {"", 0} =
                   System.cmd("git", ["config", "other.mumble.filemode", "true"], cd: path)
        end,
        xgit_add_fn: fn config_file ->
          assert :ok =
                   ConfigFile.add_entries(
                     config_file,
                     [
                       %ConfigEntry{
                         section: "other",
                         subsection: "mumble",
                         name: "filemode",
                         value: "true"
                       }
                     ]
                   )
        end
      )
    end

    test "creating a new subsection requiring escaping" do
      assert_configs_are_equal(
        initial_config: @example_config,
        git_add_fn: fn path ->
          assert {"", 0} =
                   System.cmd("git", ["config", ~s(other.mu"mb"\\le.filemode), "true"], cd: path)
        end,
        xgit_add_fn: fn config_file ->
          assert :ok =
                   ConfigFile.add_entries(
                     config_file,
                     [
                       %ConfigEntry{
                         section: "other",
                         subsection: ~s(mu"mb"\\le),
                         name: "filemode",
                         value: "true"
                       }
                     ]
                   )
        end
      )
    end

    test "replace single-valued variable with redundant replace_all?: true" do
      assert_configs_are_equal(
        initial_config: @example_config,
        git_add_fn: fn path ->
          assert {"", 0} = System.cmd("git", ["config", "core.filemode", "true"], cd: path)
        end,
        xgit_add_fn: fn config_file ->
          assert :ok =
                   ConfigFile.add_entries(
                     config_file,
                     [
                       %ConfigEntry{
                         section: "core",
                         subsection: nil,
                         name: "filemode",
                         value: "true"
                       }
                     ],
                     replace_all?: true
                   )
        end
      )
    end

    test "add to existing multivar with add?: true" do
      assert_configs_are_equal(
        initial_config: @example_config,
        git_add_fn: fn path ->
          assert {"", 0} =
                   System.cmd(
                     "git",
                     ["config", "--add", "core.gitproxy", ~s("proxy-command" for example.com)],
                     cd: path
                   )
        end,
        xgit_add_fn: fn config_file ->
          assert :ok =
                   ConfigFile.add_entries(
                     config_file,
                     [
                       %ConfigEntry{
                         section: "core",
                         subsection: nil,
                         name: "gitproxy",
                         value: ~s("proxy-command" for example.com)
                       }
                     ],
                     add?: true
                   )
        end
      )
    end

    test "replace existing multivar with add?: true" do
      assert_configs_are_equal(
        initial_config: @example_config,
        git_add_fn: fn path ->
          assert {"", 0} =
                   System.cmd(
                     "git",
                     [
                       "config",
                       "--replace-all",
                       "core.gitproxy",
                       ~s("proxy-command" for example.com)
                     ],
                     cd: path
                   )
        end,
        xgit_add_fn: fn config_file ->
          assert :ok =
                   ConfigFile.add_entries(
                     config_file,
                     [
                       %ConfigEntry{
                         section: "core",
                         subsection: nil,
                         name: "gitproxy",
                         value: ~s("proxy-command" for example.com)
                       }
                     ],
                     replace_all?: true
                   )
        end
      )
    end

    test "error: can't replace existing multivar without add? or replace_all?" do
      %{config_file_path: config_file_path} = setup_with_config!(initial_config: @example_config)

      assert {:ok, cf} = ConfigFile.start_link(config_file_path)

      assert {:error, :replacing_multivar} =
               ConfigFile.add_entries(
                 cf,
                 [
                   %ConfigEntry{
                     section: "core",
                     subsection: nil,
                     name: "gitproxy",
                     value: ~s("proxy-command" for example.com)
                   }
                 ]
               )

      assert {:ok,
              [
                %Xgit.ConfigEntry{
                  name: "gitproxy",
                  section: "core",
                  subsection: nil,
                  value: "proxy-command for kernel.org"
                },
                %Xgit.ConfigEntry{
                  name: "gitproxy",
                  section: "core",
                  subsection: nil,
                  value: "default-proxy"
                }
              ]} = ConfigFile.get_entries(cf, section: "core", name: "gitproxy")
    end

    test "error: add? and replace_all? both specified" do
      %{config_file_path: config_file_path} = setup_with_config!(initial_config: @example_config)

      assert {:ok, cf} = ConfigFile.start_link(config_file_path)

      assert_raise ArgumentError,
                   "Xgit.Util.ConfigFile.add_entries/3: add? and replace_all? can not both be true",
                   fn ->
                     ConfigFile.add_entries(
                       cf,
                       [
                         %ConfigEntry{
                           section: "core",
                           subsection: nil,
                           name: "filemode",
                           value: "true"
                         }
                       ],
                       add?: true,
                       replace_all?: true
                     )
                   end
    end

    test "error: invalid entry" do
      %{config_file_path: config_file_path} = setup_with_config!(initial_config: @example_config)

      assert {:ok, cf} = ConfigFile.start_link(config_file_path)

      assert_raise ArgumentError,
                   "Xgit.Util.ConfigFile.add_entries/3: one or more entries are invalid",
                   fn ->
                     ConfigFile.add_entries(
                       cf,
                       [
                         %ConfigEntry{
                           section: "no_underscores_allowed",
                           subsection: nil,
                           name: "filemode",
                           value: "true"
                         }
                       ]
                     )
                   end
    end
  end

  defp assert_configs_are_equal(opts) do
    initial_config = Keyword.get(opts, :initial_config)

    %{xgit_path: ref_path} = setup_with_config!(initial_config: initial_config)

    %{xgit_path: xgit_path, config_file_path: xgit_config_file_path} =
      setup_with_config!(initial_config: initial_config)

    git_add_fn = Keyword.get(opts, :git_add_fn)
    git_add_fn.(ref_path)

    assert {:ok, xgit_config_file} = ConfigFile.start_link(xgit_config_file_path)

    xgit_add_fn = Keyword.get(opts, :xgit_add_fn)
    xgit_add_fn.(xgit_config_file)

    assert_folders_are_equal(Path.join(ref_path, ".git"), Path.join(xgit_path, ".git"))
  end

  defp setup_with_config!(opts) do
    path = Keyword.get(opts, :path)

    %{xgit_path: path} = context = OnDiskRepoTestCase.repo!(path)

    config_file_path = Path.join(path, ".git/config")
    initial_config = Keyword.get(opts, :initial_config)
    File.write!(config_file_path, initial_config)

    Map.put(context, :config_file_path, config_file_path)
  end

  test "handles unknown message" do
    %{tmp_dir: tmp_dir} = TempDirTestCase.tmp_dir!()
    config_path = Path.join(tmp_dir, "config")

    File.write!(config_path, "")
    TestFileUtils.touch_back!(config_path)

    assert {:ok, cf} = ConfigFile.start_link(config_path)

    assert capture_log(fn ->
             assert {:error, :unknown_message} = GenServer.call(cf, :random_unknown_message)
           end) =~ "ConfigFile received unrecognized call :random_unknown_message"
  end
end
