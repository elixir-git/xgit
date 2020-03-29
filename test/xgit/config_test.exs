defmodule Xgit.ConfigFileTest do
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
end
