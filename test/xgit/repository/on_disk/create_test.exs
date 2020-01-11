defmodule Xgit.Repository.OnDisk.CreateTest do
  use Bitwise
  use ExUnit.Case, async: true

  alias Xgit.Repository.OnDisk
  alias Xgit.Test.OnDiskRepoTestCase
  alias Xgit.Test.TempDirTestCase

  import FolderDiff

  describe "create/1" do
    test "happy path matches command-line git" do
      %{xgit_path: ref} = OnDiskRepoTestCase.repo!()
      %{tmp_dir: xgit_root} = TempDirTestCase.tmp_dir!()

      xgit = Path.join(xgit_root, "repo")

      assert :ok = OnDisk.create(xgit)
      assert_folders_are_equal(ref, xgit)
    end

    test ".git/objects should be empty after git init in an empty repo" do
      # Adapted from git t0000-basic.sh
      %{tmp_dir: xgit_root} = TempDirTestCase.tmp_dir!()

      xgit = Path.join(xgit_root, "repo")
      assert :ok = OnDisk.create(xgit)

      assert {"", 0} = System.cmd("find", [".git/objects", "-type", "f"], cd: xgit)
    end

    test ".git/objects should have 3 subdirectories" do
      # Adapted from git t0000-basic.sh

      %{tmp_dir: xgit_root} = TempDirTestCase.tmp_dir!()

      xgit = Path.join(xgit_root, "repo")
      assert :ok = OnDisk.create(xgit)

      assert {dirs_str, 0} = System.cmd("find", [".git/objects", "-type", "d"], cd: xgit)

      dirs =
        dirs_str
        |> String.split("\n", trim: true)
        |> Enum.sort()

      assert dirs == [".git/objects", ".git/objects/info", ".git/objects/pack"]
    end

    defp check_config(path) do
      assert File.dir?(path)
      assert File.dir?(Path.join(path, ".git"))
      assert File.regular?(Path.join(path, ".git/config"))
      assert File.dir?(Path.join(path, ".git/refs"))

      refute executable?(Path.join(path, ".git/config"))

      # bare=$(cd "$1" && git config --bool core.bare)
      # worktree=$(cd "$1" && git config core.worktree) ||
      # worktree=unset

      # test "$bare" = "$2" && test "$worktree" = "$3" || {
      #   echo "expected bare=$2 worktree=$3"
      #   echo "     got bare=$bare worktree=$worktree"
      #   return 1
      # }
    end

    defp executable?(path) do
      case File.lstat(path) do
        {:ok, %File.Stat{mode: mode}} -> (mode &&& 0o100) == 0o100
        _ -> false
      end
    end

    test "plain" do
      # Adapted from git t0001-init.sh

      %{tmp_dir: xgit_root} = TempDirTestCase.tmp_dir!()

      xgit = Path.join(xgit_root, "repo")
      assert :ok = OnDisk.create(xgit)

      check_config(xgit)
    end

    test "error: no work_dir" do
      assert_raise FunctionClauseError, fn ->
        OnDisk.create(nil)
      end
    end

    test "error: work dir exists already" do
      %{xgit_path: xgit_root} = OnDiskRepoTestCase.repo!()
      xgit = Path.join(xgit_root, "repo")

      File.mkdir_p!(xgit)
      assert {:error, :work_dir_must_not_exist} = OnDisk.create(xgit)
    end
  end
end
