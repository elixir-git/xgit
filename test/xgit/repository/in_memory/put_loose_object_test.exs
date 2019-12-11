defmodule Xgit.Repository.InMemory.PutLooseObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.ContentSource
  alias Xgit.Core.FileContentSource
  alias Xgit.Core.Object
  alias Xgit.Repository.InMemory
  alias Xgit.Repository.Storage

  describe "put_loose_object/2" do
    # Also tests corresonding cases of get_object/2.
    @test_content 'test content\n'
    @test_content_id "d670460b4b4aece5915caf5c68d12f560a9fe3e4"

    test "happy path: put and get back" do
      assert {:ok, repo} = InMemory.start_link()

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      assert :ok = Storage.put_loose_object(repo, object)

      assert {:ok, ^object} = Storage.get_object(repo, @test_content_id)
    end

    test "happy path: reads file into memory" do
      Temp.track!()
      path = Temp.path!()

      content =
        1..1000
        |> Enum.map(fn _ -> "foobar" end)
        |> Enum.join()

      File.write!(path, content)
      content_id = "b9fce9aed947fd9f5a160c18cf2983fe455f8daf"
      # ^ lifted from running the corresponding on-disk test.

      assert {:ok, repo} = InMemory.start_link()

      fcs = FileContentSource.new(path)
      object = %Object{type: :blob, content: fcs, size: ContentSource.length(fcs), id: content_id}
      assert :ok = Storage.put_loose_object(repo, object)

      content_as_binary = :binary.bin_to_list(content)
      content_size = byte_size(content)

      assert {ok,
              %Object{
                type: :blob,
                content: ^content_as_binary,
                size: ^content_size,
                id: ^content_id
              }} = Storage.get_object(repo, content_id)

      assert Object.valid?(object)
    end

    test "error: object exists already" do
      assert {:ok, repo} = InMemory.start_link()

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      assert :ok = Storage.put_loose_object(repo, object)

      assert {:error, :object_exists} = Storage.put_loose_object(repo, object)

      assert {:ok, ^object} = Storage.get_object(repo, @test_content_id)
      assert Object.valid?(object)
    end
  end
end
