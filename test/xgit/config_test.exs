defmodule Xgit.ConfigTest do
  use ExUnit.Case, async: true

  alias Xgit.Config
  alias Xgit.ConfigEntry
  alias Xgit.Repository.InMemory
  alias Xgit.Repository.Storage

  setup do
    {:ok, repo} = InMemory.start_link()
    {:ok, repo: repo}
  end

  describe "get_string_list/4" do
    test "empty case (no subsection)", %{repo: repo} do
      assert [] = Config.get_string_list(repo, "core", "blah")
    end

    test "empty case (with subsection)", %{repo: repo} do
      assert [] = Config.get_string_list(repo, "core", "subsection", "blah")
    end

    test "strings exist (no subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: "foo"
        })

      :ok =
        Storage.add_config_entry(
          repo,
          %ConfigEntry{
            section: "test",
            subsection: nil,
            name: "blah",
            value: "foo2"
          },
          add?: true
        )

      assert ["foo", "foo2"] = Config.get_string_list(repo, "test", "blah")
    end

    test "strings exist (with subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: "sub",
          name: "blah",
          value: "foo"
        })

      :ok =
        Storage.add_config_entry(
          repo,
          %ConfigEntry{
            section: "test",
            subsection: "sub",
            name: "blah",
            value: "foo2"
          },
          add?: true
        )

      assert ["foo", "foo2"] = Config.get_string_list(repo, "test", "sub", "blah")
    end
  end

  describe "get_string/4" do
    test "empty case (no subsection)", %{repo: repo} do
      assert Config.get_string(repo, "core", "blah") == nil
    end

    test "empty case (with subsection)", %{repo: repo} do
      assert Config.get_string(repo, "core", "subsection", "blah") == nil
    end

    test "single string exists (no subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: "foo"
        })

      assert Config.get_string(repo, "test", "blah") == "foo"
    end

    test "single string exists (with subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: "sub",
          name: "blah",
          value: "foo"
        })

      assert Config.get_string(repo, "test", "sub", "blah") == "foo"
    end

    test "single string exists (no = sign)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: nil
        })

      assert Config.get_string(repo, "test", "blah") == :empty
    end

    test "single string exists (no value after =)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: ""
        })

      assert Config.get_string(repo, "test", "blah") == ""
    end

    test "multiple strings exist (no subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: "foo"
        })

      :ok =
        Storage.add_config_entry(
          repo,
          %ConfigEntry{
            section: "test",
            subsection: nil,
            name: "blah",
            value: "foo2"
          },
          add?: true
        )

      assert Config.get_string(repo, "test", "blah") == nil
    end

    test "multiple strings exist (with subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: "sub",
          name: "blah",
          value: "foo"
        })

      :ok =
        Storage.add_config_entry(
          repo,
          %ConfigEntry{
            section: "test",
            subsection: "sub",
            name: "blah",
            value: "foo2"
          },
          add?: true
        )

      assert Config.get_string(repo, "test", "sub", "blah") == nil
    end
  end

  describe "get_integer/5" do
    test "empty case (no subsection)", %{repo: repo} do
      assert Config.get_integer(repo, "core", "blah", 42) == 42
    end

    test "empty case (with subsection)", %{repo: repo} do
      assert Config.get_integer(repo, "core", "subsection", "blah", 59) == 59
    end

    test "single integer string exists (no subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: "43"
        })

      assert Config.get_integer(repo, "test", "blah", 52) == 43
    end

    test "single integer string exists (with subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: "sub",
          name: "blah",
          value: "-87"
        })

      assert Config.get_integer(repo, "test", "sub", "blah", 87) == -87
    end

    test "single invalid string exists (no subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: "33.5"
        })

      assert Config.get_integer(repo, "test", "blah", 56) == 56
    end

    test "single invalid string exists (with subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: "sub",
          name: "blah",
          value: "foo"
        })

      assert Config.get_integer(repo, "test", "sub", "blah", 314) == 314
    end

    test "multiple strings exist (no subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: "14"
        })

      :ok =
        Storage.add_config_entry(
          repo,
          %ConfigEntry{
            section: "test",
            subsection: nil,
            name: "blah",
            value: "15"
          },
          add?: true
        )

      assert Config.get_integer(repo, "test", "blah", 13) == 13
    end

    test "multiple strings exist (with subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: "sub",
          name: "blah",
          value: "22"
        })

      :ok =
        Storage.add_config_entry(
          repo,
          %ConfigEntry{
            section: "test",
            subsection: "sub",
            name: "blah",
            value: "24"
          },
          add?: true
        )

      assert Config.get_integer(repo, "test", "sub", "blah", 97) == 97
    end

    test "scale with K suffix" do
      flunk("unimplemented")
    end

    test "scale with M suffix" do
      flunk("unimplemented")
    end

    test "scale with G suffix" do
      flunk("unimplemented")
    end
  end

  describe "get_boolean/5" do
    test "empty case (no subsection)", %{repo: repo} do
      assert Config.get_boolean(repo, "core", "blah", true) == true
    end

    test "empty case (with subsection)", %{repo: repo} do
      assert Config.get_boolean(repo, "core", "subsection", "blah", false) == false
    end

    test "single boolean string exists (no subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: "true"
        })

      assert Config.get_boolean(repo, "test", "blah", false) == true
    end

    test "single boolean string exists (with subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: "sub",
          name: "blah",
          value: "false"
        })

      assert Config.get_boolean(repo, "test", "sub", "blah", true) == false
    end

    test "single invalid string exists (no subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: "33"
        })

      assert Config.get_boolean(repo, "test", "blah", false) == false
    end

    test "single invalid string exists (with subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: "sub",
          name: "blah",
          value: "foo"
        })

      assert Config.get_boolean(repo, "test", "sub", "blah", true) == true
    end

    defp check_true_alias(repo, value) do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: value
        })

      assert Config.get_boolean(repo, "test", "blah", false) == true
    end

    defp check_false_alias(repo, value) do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: value
        })

      assert Config.get_boolean(repo, "test", "blah", true) == false
    end

    test "aliases for true", %{repo: repo} do
      check_true_alias(repo, "yes")
      check_true_alias(repo, "yEs")
      check_true_alias(repo, "on")
      check_true_alias(repo, "ON")
      check_true_alias(repo, "TrUe")
      check_true_alias(repo, "1")
    end

    test "aliases for false", %{repo: repo} do
      check_false_alias(repo, "no")
      check_false_alias(repo, "nO")
      check_false_alias(repo, "off")
      check_false_alias(repo, "oFf")
      check_false_alias(repo, "fAlSe")
      check_false_alias(repo, "0")
    end

    test "multiple strings exist (no subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: nil,
          name: "blah",
          value: "true"
        })

      :ok =
        Storage.add_config_entry(
          repo,
          %ConfigEntry{
            section: "test",
            subsection: nil,
            name: "blah",
            value: "false"
          },
          add?: true
        )

      assert Config.get_boolean(repo, "test", "blah", false) == false
    end

    test "multiple strings exist (with subsection)", %{repo: repo} do
      :ok =
        Storage.add_config_entry(repo, %ConfigEntry{
          section: "test",
          subsection: "sub",
          name: "blah",
          value: "false"
        })

      :ok =
        Storage.add_config_entry(
          repo,
          %ConfigEntry{
            section: "test",
            subsection: "sub",
            name: "blah",
            value: "true"
          },
          add?: true
        )

      assert Config.get_boolean(repo, "test", "sub", "blah", true) == true
    end

    test "true: value without =" do
      flunk("unimplemented")
    end

    test "false: value with = but nothing further" do
      flunk("unimplemented")
    end
  end
end
