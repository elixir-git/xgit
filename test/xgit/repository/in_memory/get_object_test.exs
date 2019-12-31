defmodule Xgit.Repository.InMemory.GetObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.Repository.InMemory
  alias Xgit.Repository.Storage

  describe "get_object/2" do
    # Happy paths involving existing items are tested in put_loose_object_test.

    test "error: no such object" do
      assert {:ok, repo} = InMemory.start_link()

      assert {:error, :not_found} =
               Storage.get_object(repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
    end
  end
end
