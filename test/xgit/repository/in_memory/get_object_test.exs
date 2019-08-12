defmodule Xgit.Repository.InMemory.GetObjectTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Repository
  alias Xgit.Repository.InMemory

  describe "get_object/2" do
    # Happy paths involving existing items are tested in put_loose_object_test.

    test "error: no such object" do
      assert {:ok, repo} = InMemory.start_link()

      assert {:error, :not_found} =
               Repository.get_object(repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
    end
  end
end
