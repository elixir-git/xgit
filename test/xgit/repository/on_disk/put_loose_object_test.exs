defmodule Xgit.Repository.OnDisk.PutLooseObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.ContentSource
  alias Xgit.FileContentSource
  alias Xgit.Object
  alias Xgit.Repository.Storage
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  describe "put_loose_object/2" do
    @test_content 'test content\n'
    @test_content_id "d670460b4b4aece5915caf5c68d12f560a9fe3e4"

    test "happy path matches command-line git (small file)" do
      %{xgit_path: ref} = OnDiskRepoTestCase.repo!()
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      Temp.track!()
      path = Temp.path!()
      File.write!(path, "test content\n")

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: ref)
      assert String.trim(output) == @test_content_id

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      assert :ok = Storage.put_loose_object(repo, object)

      assert_folders_are_equal(ref, xgit)

      assert {:ok,
              %Object{type: :blob, content: content_read_back, size: 13, id: @test_content_id} =
                object2} = Storage.get_object(repo, @test_content_id)

      assert Object.valid?(object2)

      content2 =
        content_read_back
        |> ContentSource.stream()
        |> Enum.to_list()

      assert content2 == @test_content
    end

    test "happy path matches command-line git (large file)" do
      %{xgit_path: ref} = OnDiskRepoTestCase.repo!()
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      Temp.track!()
      path = Temp.path!()

      content =
        1..1000
        |> Enum.map(fn _ -> "foobar" end)
        |> Enum.join()

      File.write!(path, content)

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: ref)
      content_id = String.trim(output)

      fcs = FileContentSource.new(path)
      object = %Object{type: :blob, content: fcs, size: ContentSource.length(fcs), id: content_id}
      assert :ok = Storage.put_loose_object(repo, object)

      assert_folders_are_equal(ref, xgit)
    end

    test "error: can't create objects dir" do
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      objects_dir = Path.join([xgit, ".git", "objects", String.slice(@test_content_id, 0, 2)])
      File.mkdir_p!(Path.join([xgit, ".git", "objects"]))
      File.write!(objects_dir, "sand in the gears")

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      assert {:error, :cant_create_file} = Storage.put_loose_object(repo, object)
    end

    test "error: object exists already" do
      %{xgit_path: xgit, xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      objects_dir = Path.join([xgit, ".git", "objects", String.slice(@test_content_id, 0, 2)])
      File.mkdir_p!(objects_dir)

      File.write!(
        Path.join(objects_dir, String.slice(@test_content_id, 2, 38)),
        "sand in the gears"
      )

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      assert {:error, :object_exists} = Storage.put_loose_object(repo, object)
    end
  end
end
