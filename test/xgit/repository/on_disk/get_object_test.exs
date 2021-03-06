defmodule Xgit.Repository.OnDisk.GetObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.ContentSource
  alias Xgit.Object
  alias Xgit.Repository.OnDisk
  alias Xgit.Repository.Storage
  alias Xgit.Test.OnDiskRepoTestCase

  describe "get_object/2" do
    test "happy path: can read from command-line git (small file)" do
      %{xgit_path: ref} = OnDiskRepoTestCase.repo!()

      Temp.track!()
      path = Temp.path!()
      File.write!(path, "test content\n")

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: ref)
      test_content_id = String.trim(output)

      assert {:ok, repo} = OnDisk.start_link(work_dir: ref)

      assert {:ok,
              %Object{type: :blob, content: test_content, size: 13, id: ^test_content_id} = object} =
               Storage.get_object(repo, test_content_id)

      rendered_content =
        test_content
        |> ContentSource.stream()
        |> Enum.to_list()

      assert rendered_content == 'test content\n'
      assert ContentSource.length(test_content) == 13
    end

    test "happy path: can read from command-line git (large file)" do
      %{xgit_path: ref} = OnDiskRepoTestCase.repo!()

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
               Storage.get_object(repo, content_id)

      assert Object.valid?(object)

      test_content_str =
        test_content
        |> ContentSource.stream()
        |> Enum.to_list()
        |> to_string()

      assert test_content_str == content
    end

    test "error: no such file" do
      %{xgit_repo: repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :not_found} =
               Storage.get_object(repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
    end

    test "error: invalid object (not ZIP compressed)" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()
      assert_zip_data_is_invalid(xgit, "blob ")
    end

    test "error: invalid object (ZIP compressed, but incomplete)" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

      # "blob "
      assert_zip_data_is_invalid(xgit, <<120, 1, 75, 202, 201, 79, 82, 0, 0, 5, 208, 1, 192>>)
    end

    test "error: invalid object (ZIP compressed object type without length)" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

      # "blob"
      assert_zip_data_is_invalid(
        xgit,
        <<120, 156, 75, 202, 201, 79, 2, 0, 4, 16, 1, 160>>
      )
    end

    test "error: invalid object (ZIP compressed, but invalid object type)" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

      # "blog 13\0"
      assert_zip_data_is_invalid(
        xgit,
        <<120, 1, 75, 202, 201, 79, 87, 48, 52, 102, 0, 0, 12, 34, 2, 41>>
      )
    end

    test "error: invalid object (ZIP compressed, but invalid object type 2)" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

      # "blobx 1234\0"
      assert_zip_data_is_invalid(
        xgit,
        <<120, 1, 75, 202, 201, 79, 170, 80, 48, 52, 50, 54, 97, 0, 0, 22, 54, 3, 2>>
      )
    end

    test "error: invalid object (ZIP compressed, but invalid length)" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

      # "blob 13 \0" (extra space)
      assert_zip_data_is_invalid(
        xgit,
        <<120, 1, 75, 202, 201, 79, 82, 48, 52, 86, 96, 0, 0, 14, 109, 2, 68>>
      )
    end

    test "error: invalid object (ZIP compressed, but invalid length 2)" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

      # "blob 12x34\0"
      assert_zip_data_is_invalid(
        xgit,
        <<120, 1, 75, 202, 201, 79, 82, 48, 52, 170, 48, 54, 97, 0, 0, 21, 81, 3, 2>>
      )
    end

    test "error: invalid object (ZIP compressed, but no length)" do
      %{xgit_path: xgit} = OnDiskRepoTestCase.repo!()

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
             Storage.get_object(repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
  end
end
