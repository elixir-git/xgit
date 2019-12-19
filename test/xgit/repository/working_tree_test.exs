defmodule Xgit.Repository.WorkingTreeTest do
  use ExUnit.Case, async: true

  alias Xgit.Repository.InMemory
  alias Xgit.Repository.InvalidRepositoryError
  alias Xgit.Repository.WorkingTree

  import ExUnit.CaptureLog

  describe "valid?/1" do
    # Happy path covered by start_link/1 test below.

    test "different process" do
      {:ok, not_working_tree} = GenServer.start_link(NotValid, nil)
      refute WorkingTree.valid?(not_working_tree)
    end

    test "different types" do
      refute WorkingTree.valid?(42)
      refute WorkingTree.valid?("so-called working tree")
    end
  end

  describe "start_link/1" do
    test "happy path: starts and is valid" do
      Temp.track!()
      path = Temp.path!()

      {:ok, repo} = InMemory.start_link()

      assert {:ok, working_tree} = WorkingTree.start_link(repo, path)
      assert is_pid(working_tree)

      assert WorkingTree.valid?(working_tree)
      assert File.dir?(path)
    end

    test "handles unknown message" do
      Temp.track!()
      path = Temp.path!()

      {:ok, repo} = InMemory.start_link()

      assert {:ok, working_tree} = WorkingTree.start_link(repo, path)

      assert capture_log(fn ->
               assert {:error, :unknown_message} =
                        GenServer.call(working_tree, :random_unknown_message)
             end) =~ "WorkingTree received unrecognized call :random_unknown_message"
    end

    test "error: repository isn't" do
      Temp.track!()
      path = Temp.path!()

      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        WorkingTree.start_link(not_repo, path)
      end
    end

    test "error: can't create working dir" do
      Temp.track!()
      path = Temp.path!()
      File.write!(path, "not a directory")

      {:ok, repo} = InMemory.start_link()
      assert {:error, {:mkdir, :eexist}} = WorkingTree.start_link(repo, path)
    end
  end
end
