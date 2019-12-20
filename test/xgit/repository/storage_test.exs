defmodule Xgit.Repository.StorageTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Repository.InvalidRepositoryError
  alias Xgit.Repository.Storage

  describe "assert_valid/1" do
    test "raises InvalidRepositoryError when invalid PID" do
      {:ok, pid} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        Storage.assert_valid(pid)
      end
    end
  end
end
