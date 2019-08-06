defmodule Xgit.Repository.OnDisk.GetObjectTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Core.Object
  alias Xgit.Repository
  alias Xgit.Repository.OnDisk

  describe "get_object/2" do
    test "happy path: can read from command-line git (small file)", %{ref: ref} do
      Temp.track!()
      path = Temp.path!()
      File.write!(path, "test content\n")

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: ref)
      test_content_id = String.trim(output)

      assert {:ok, repo} = OnDisk.start_link(work_dir: ref)

      assert {:ok,
              %Object{type: :blob, content: test_content, size: 13, id: ^test_content_id} = object} =
               Repository.get_object(repo, test_content_id)

      assert Enum.to_list(test_content) == 'test content\n'
    end

    test "happy path: can read from command-line git (large file)", %{ref: ref} do
      Temp.track!()
      path = Temp.path!()

      content =
        1..1000
        |> Enum.map(fn _ -> "foobar" end)
        |> Enum.join()

      File.write!(path, content)

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: ref)
      content_id = String.trim(output)

      assert {:ok, repo} = OnDisk.start_link(work_dir: ref)

      assert {:ok,
              %Object{type: :blob, content: test_content, size: 6000, id: ^content_id} = object} =
               Repository.get_object(repo, content_id)

      test_content_str =
        test_content
        |> Enum.to_list()
        |> to_string()

      assert test_content_str == content
    end

    test "error: no such file", %{ref: ref} do
      assert {:ok, repo} = OnDisk.start_link(work_dir: ref)

      assert {:error, :not_found} =
               Repository.get_object(repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
    end

    test "error: invalid object (not ZIP compressed)", %{xgit: xgit} do
      assert_zip_data_is_invalid(xgit, "blob ")
    end

    test "error: invalid object (ZIP compressed, but incomplete)", %{xgit: xgit} do
      # "blob "
      assert_zip_data_is_invalid(xgit, <<120, 1, 75, 202, 201, 79, 82, 0, 0, 5, 208, 1, 192>>)
    end

    test "error: invalid object (ZIP compressed, but invalid object type)", %{xgit: xgit} do
      # "blog 13\0"
      assert_zip_data_is_invalid(
        xgit,
        <<120, 1, 75, 202, 201, 79, 87, 48, 52, 102, 0, 0, 12, 34, 2, 41>>
      )
    end

    test "error: invalid object (ZIP compressed, but invalid object type 2)", %{xgit: xgit} do
      # "blobx 1234\0"
      assert_zip_data_is_invalid(
        xgit,
        <<120, 1, 75, 202, 201, 79, 170, 80, 48, 52, 50, 54, 97, 0, 0, 22, 54, 3, 2>>
      )
    end

    test "error: invalid object (ZIP compressed, but invalid length)", %{xgit: xgit} do
      # "blob 13 \0" (extra space)
      assert_zip_data_is_invalid(
        xgit,
        <<120, 1, 75, 202, 201, 79, 82, 48, 52, 86, 96, 0, 0, 14, 109, 2, 68>>
      )
    end

    test "error: invalid object (ZIP compressed, but invalid length 2)", %{xgit: xgit} do
      # "blob 12x34\0"
      assert_zip_data_is_invalid(
        xgit,
        <<120, 1, 75, 202, 201, 79, 82, 48, 52, 170, 48, 54, 97, 0, 0, 21, 81, 3, 2>>
      )
    end

    test "error: invalid object (ZIP compressed, but no length)", %{xgit: xgit} do
      # "blob \0" (space, but no length)
      assert_zip_data_is_invalid(xgit, <<120, 1, 75, 202, 201, 79, 82, 96, 0, 0, 7, 144, 1, 192>>)
    end
  end

  defp assert_zip_data_is_invalid(xgit, data) do
    path = Path.join([xgit, ".git", "objects", "5c"])
    File.mkdir_p!(path)

    File.write!(Path.join(path, "b5d77be2d92c7368038dac67e648a69e0a654d"), data)

    assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

    assert {:error, :invalid_object} =
             Repository.get_object(repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
  end
end
