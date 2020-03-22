defmodule Xgit.Repository.Test.ConfigTest do
  @moduledoc false

  # Not normally part of the public API, but available for implementors of
  # `Xgit.Repository.Storage` behaviour modules. Tests the callbacks related to
  # `Xgit.ConfigEntry` to ensure correct implementation of the core contracts.
  # Other tests may be necessary to ensure interop. (For example, the on-disk
  # repository test code adds more tests to ensure correct interop with
  # command-line git.)

  # Users of this module must provide a `setup` callback that provides a
  # `repo` member. This repository may be of any type, but should be "empty."
  # An empty repo has the same data structures as an on-disk repo created
  # via `git init` in a previously-empty directory.

  # IMPORTANT: We assume that the repo is initialized with a minimal configuration
  # that corresponds to the following:

  # [core]
  #     repositoryformatversion = 0
  #     filemode = true
  #     bare = false
  #     logallrefupdates = true

  # The official definition for this is located in on_disk_repo_test_case.ex,
  # private function rewrite_config/1.

  import Xgit.Util.SharedTestCase

  define_shared_tests do
    alias Xgit.ConfigEntry
    alias Xgit.Repository.Storage

    describe "get_config_entries/2" do
      test "default case returns expected initial case", %{repo: repo} do
        assert {:ok, [_ | _] = config_entries} = Storage.get_config_entries(repo)

        assert [
                 %ConfigEntry{section: "core", subsection: nil, name: "bare", value: "false"},
                 %ConfigEntry{section: "core", subsection: nil, name: "filemode", value: "true"},
                 %ConfigEntry{
                   section: "core",
                   subsection: nil,
                   name: "logallrefupdates",
                   value: "true"
                 },
                 %ConfigEntry{
                   section: "core",
                   subsection: nil,
                   name: "repositoryformatversion",
                   value: "0"
                 }
               ] = Enum.sort(config_entries)
      end

      test "can filter by section", %{repo: repo} do
        assert {:ok, [_ | _] = config_entries} = Storage.get_config_entries(repo, section: "core")

        assert [
                 %ConfigEntry{section: "core", subsection: nil, name: "bare", value: "false"},
                 %ConfigEntry{section: "core", subsection: nil, name: "filemode", value: "true"},
                 %ConfigEntry{
                   section: "core",
                   subsection: nil,
                   name: "logallrefupdates",
                   value: "true"
                 },
                 %ConfigEntry{
                   section: "core",
                   subsection: nil,
                   name: "repositoryformatversion",
                   value: "0"
                 }
               ] = Enum.sort(config_entries)
      end

      test "can filter by subsection", %{repo: repo} do
        assert {:ok, [] = _config_entries} =
                 Storage.get_config_entries(repo, section: "core", subsection: "mumble")
      end

      test "can filter by section + name", %{repo: repo} do
        assert {:ok, [_ | _] = config_entries} =
                 Storage.get_config_entries(repo, section: "core", name: "bare")

        assert [
                 %ConfigEntry{section: "core", subsection: nil, name: "bare", value: "false"}
               ] = Enum.sort(config_entries)
      end
    end

    describe "add_config_entry/3" do
      test "basic case with default options", %{repo: repo} do
        assert :ok =
                 Storage.add_config_entry(
                   repo,
                   %ConfigEntry{
                     section: "core",
                     subsection: nil,
                     name: "filemode",
                     value: "true"
                   }
                 )

        assert {:ok, config_entries} = Storage.get_config_entries(repo)

        assert [
                 %ConfigEntry{section: "core", subsection: nil, name: "bare", value: "false"},
                 %ConfigEntry{section: "core", subsection: nil, name: "filemode", value: "true"},
                 %ConfigEntry{
                   section: "core",
                   subsection: nil,
                   name: "logallrefupdates",
                   value: "true"
                 },
                 %ConfigEntry{
                   section: "core",
                   subsection: nil,
                   name: "repositoryformatversion",
                   value: "0"
                 }
               ] = Enum.sort(config_entries)
      end

      test "add?: true", %{repo: repo} do
        # Yes, this example is nonsense.

        assert :ok =
                 Storage.add_config_entry(
                   repo,
                   %ConfigEntry{
                     section: "core",
                     subsection: nil,
                     name: "filemode",
                     value: "false"
                   },
                   add?: true
                 )

        assert {:ok, config_entries} =
                 Storage.get_config_entries(repo,
                   section: "core",
                   subsection: nil,
                   name: "filemode"
                 )

        # Spec is agnostic as to whether new items get inserted at end of overall list
        # or elsewhere; only that the values for this entry must be sorted in the order added.

        assert [
                 %ConfigEntry{section: "core", subsection: nil, name: "filemode", value: "true"},
                 %ConfigEntry{section: "core", subsection: nil, name: "filemode", value: "false"}
               ] = config_entries
      end

      test "replace_all?: true", %{repo: repo} do
        # Build upon previous nonsense example. Have multiple values and then replace them all.

        assert :ok =
                 Storage.add_config_entry(
                   repo,
                   %ConfigEntry{
                     section: "core",
                     subsection: nil,
                     name: "filemode",
                     value: "false"
                   },
                   add?: true
                 )

        # Not testing output; duplicates previous test.

        assert :ok =
                 Storage.add_config_entry(
                   repo,
                   %ConfigEntry{
                     section: "core",
                     subsection: nil,
                     name: "filemode",
                     value: "42"
                   },
                   replace_all?: true
                 )

        assert {:ok, config_entries} =
                 Storage.get_config_entries(repo,
                   section: "core",
                   subsection: nil,
                   name: "filemode"
                 )

        # Spec is agnostic as to whether new items get inserted at end of overall list
        # or elsewhere; only that the values for this entry must be sorted in the order added.

        assert [
                 %ConfigEntry{section: "core", subsection: nil, name: "filemode", value: "42"}
               ] = config_entries
      end

      test "error: replacing multivar", %{repo: repo} do
        # Build upon previous nonsense example. Have multiple values and then
        # attempt to replace them all but without the replace_all?: true flag.

        assert :ok =
                 Storage.add_config_entry(
                   repo,
                   %ConfigEntry{
                     section: "core",
                     subsection: nil,
                     name: "filemode",
                     value: "false"
                   },
                   add?: true
                 )

        # Not testing output; duplicates previous test.

        assert {:error, :replacing_multivar} =
                 Storage.add_config_entry(
                   repo,
                   %ConfigEntry{
                     section: "core",
                     subsection: nil,
                     name: "filemode",
                     value: "42"
                   }
                 )

        assert {:ok, config_entries} =
                 Storage.get_config_entries(repo,
                   section: "core",
                   subsection: nil,
                   name: "filemode"
                 )

        # Spec is agnostic as to whether new items get inserted at end of overall list
        # or elsewhere; only that the values for this entry must be sorted in the order added.

        assert [
                 %ConfigEntry{section: "core", subsection: nil, name: "filemode", value: "true"},
                 %ConfigEntry{section: "core", subsection: nil, name: "filemode", value: "false"}
               ] = config_entries
      end

      test "error: invalid entry", %{repo: repo} do
        assert_raise ArgumentError,
                     "Xgit.Repository.Storage.add_config_entry/3: entry is invalid",
                     fn ->
                       Storage.add_config_entry(
                         repo,
                         %ConfigEntry{
                           section: "no spaces allowed",
                           subsection: nil,
                           name: "filemode",
                           value: "true"
                         }
                       )
                     end
      end
    end
  end
end
