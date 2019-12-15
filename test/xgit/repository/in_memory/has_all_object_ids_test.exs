defmodule Xgit.Repository.InMemory.HasAllObjectIdsTest do
  use ExUnit.Case, async: true

  alias Xgit.Object
  alias Xgit.Repository.InMemory
  alias Xgit.Repository.Storage

  describe "has_all_object_ids?/2" do
    @test_content 'test content\n'
    @test_content_id "d670460b4b4aece5915caf5c68d12f560a9fe3e4"

    setup do
      assert {:ok, repo} = InMemory.start_link()

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      assert :ok = Storage.put_loose_object(repo, object)

      # Yes, the hash is wrong, but we'll ignore that for now.
      object = %Object{
        type: :blob,
        content: @test_content,
        size: 15,
        id: "c1e116090ad56f172370351ab3f773eb0f1fe89e"
      }

      assert :ok = Storage.put_loose_object(repo, object)

      {:ok, repo: repo}
    end

    test "happy path: zero object IDs", %{repo: repo} do
      assert Storage.has_all_object_ids?(repo, [])
    end

    test "happy path: one object ID", %{repo: repo} do
      assert Storage.has_all_object_ids?(repo, [@test_content_id])
    end

    test "happy path: two object IDs", %{repo: repo} do
      assert Storage.has_all_object_ids?(repo, [
               @test_content_id,
               "c1e116090ad56f172370351ab3f773eb0f1fe89e"
             ])
    end

    test "happy path: partial match", %{repo: repo} do
      refute Storage.has_all_object_ids?(repo, [
               @test_content_id,
               "b9e3a9e3ea7dde01d652f899a783b75a1518564c"
             ])
    end

    test "happy path: no match", %{repo: repo} do
      refute Storage.has_all_object_ids?(repo, [
               @test_content_id,
               "6ee878a55ed36e2cda2c68452d2336ce3bd692d1"
             ])
    end
  end
end
