defmodule Xgit.Repository.OnDisk.PutLooseObjectTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Core.ContentSource
  alias Xgit.Core.FileContentSource
  alias Xgit.Core.Object
  alias Xgit.Repository
  alias Xgit.Repository.OnDisk

  import FolderDiff

  describe "put_loose_object/2" do
    @test_content 'test content\n'
    @test_content_id "d670460b4b4aece5915caf5c68d12f560a9fe3e4"

    test "happy path matches command-line git (small file)", %{ref: ref, xgit: xgit} do
      Temp.track!()
      path = Temp.path!()
      File.write!(path, "test content\n")

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: ref)
      assert String.trim(output) == @test_content_id

      assert :ok = OnDisk.create(xgit)
      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      assert :ok = Repository.put_loose_object(repo, object)

      assert_folders_are_equal(ref, xgit)
    end

    test "happy path matches command-line git (large file)", %{ref: ref, xgit: xgit} do
      Temp.track!()
      path = Temp.path!()

      content =
        1..1000
        |> Enum.map(fn _ -> "foobar" end)
        |> Enum.join()

      File.write!(path, content)

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: ref)
      content_id = String.trim(output)

      assert :ok = OnDisk.create(xgit)
      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      fcs = FileContentSource.new(path)
      object = %Object{type: :blob, content: fcs, size: ContentSource.length(fcs), id: content_id}
      assert :ok = Repository.put_loose_object(repo, object)

      assert_folders_are_equal(ref, xgit)
    end

    test "error: can't create objects dir", %{xgit: xgit} do
      assert :ok = OnDisk.create(xgit)
      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      objects_dir = Path.join([xgit, ".git", "objects", String.slice(@test_content_id, 0, 2)])
      File.mkdir_p!(Path.join([xgit, ".git", "objects"]))
      File.write!(objects_dir, "sand in the gears")

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      assert {:error, :cant_create_dir} = Repository.put_loose_object(repo, object)
    end

    test "error: object exists already", %{xgit: xgit} do
      assert :ok = OnDisk.create(xgit)
      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      objects_dir = Path.join([xgit, ".git", "objects", String.slice(@test_content_id, 0, 2)])
      File.mkdir_p!(objects_dir)

      File.write!(
        Path.join(objects_dir, String.slice(@test_content_id, 2, 38)),
        "sand in the gears"
      )

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      assert {:error, :object_exists} = Repository.put_loose_object(repo, object)
    end
  end
end
