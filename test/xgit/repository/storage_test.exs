defmodule Xgit.Repository.StorageTest do
  use ExUnit.Case, async: true

  alias Xgit.Repository.InMemory
  alias Xgit.Repository.InvalidRepositoryError
  alias Xgit.Repository.Storage

  describe "assert_valid/1" do
    test "remembers a previously valid PID" do
      {:ok, repo} = InMemory.start_link()

      assert {:xgit_repo, repo} = Storage.assert_valid(repo)
      assert {:xgit_repo, repo} = Storage.assert_valid({:xgit_repo, repo})
      assert Storage.valid?({:xgit_repo, repo})
    end

    test "raises InvalidRepositoryError when invalid PID" do
      {:ok, pid} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        Storage.assert_valid(pid)
      end
    end
  end
end
