defmodule Xgit.Repository.OnDisk.PutLooseObjectTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Core.Object
  alias Xgit.Repository
  alias Xgit.Repository.OnDisk

  import FolderDiff

  describe "put_loose_object/2" do
    @test_content 'test content\n'
    @test_content_id "d670460b4b4aece5915caf5c68d12f560a9fe3e4"

    test "happy path matches command-line git", %{ref: ref, xgit: xgit} do
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

    # test "error: no work_dir" do
    #   assert_raise FunctionClauseError, fn ->
    #     OnDisk.create(nil)
    #   end
    # end
    #
    # test "error: work dir exists already", %{xgit: xgit} do
    #   File.mkdir_p!(xgit)
    #
    #   assert {:error, "work_dir must be a directory that doesn't already exist"} =
    #            OnDisk.create(xgit)
    # end
  end
end
