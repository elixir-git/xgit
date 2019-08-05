defmodule Xgit.Util.UnzipStreamTest do
  use ExUnit.Case, async: true

  alias Xgit.Util.UnzipStream

  @test_content_path Path.join(File.cwd!(), "test/fixtures/test_content.zip")
  @large_content_path Path.join(File.cwd!(), "test/fixtures/LICENSE_blob.zip")

  describe "unzip/1" do
    test "happy path (small file)" do
      assert 'blob 13\0test content\n' =
               @test_content_path
               |> File.stream!([:binary])
               |> UnzipStream.unzip()
               |> Enum.to_list()
    end

    test "happy path (large file)" do
      license = File.read!("LICENSE")

      assert 'blob 11357\0#{license}' ==
               @large_content_path
               |> File.stream!([:binary])
               |> UnzipStream.unzip()
               |> Enum.to_list()
    end

    test "error: file isn't a zip" do
      assert_raise ErlangError, "Erlang error: :data_error", fn ->
        "LICENSE"
        |> File.stream!([:binary])
        |> UnzipStream.unzip()
        |> Enum.to_list()
      end
    end
  end
end
