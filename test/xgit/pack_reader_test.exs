defmodule Xgit.PackReaderTest do
  use ExUnit.Case, async: true

  alias Xgit.ContentSource
  alias Xgit.Object
  alias Xgit.PackReader
  alias Xgit.PackReader.Entry, as: PackReaderEntry

  @pack_34be9032_path "test/fixtures/pack-34be9032ac282b11fa9babdc2b2a93ca996c9c2f.pack"
  @pack_index_v1_34be9032_path "test/fixtures/pack-34be9032ac282b11fa9babdc2b2a93ca996c9c2f.idx"
  @pack_index_v2_34be9032_path "test/fixtures/pack-34be9032ac282b11fa9babdc2b2a93ca996c9c2f.idxV2"

  describe "open/2 and index functions" do
    test "error: index file doesn't exist" do
      assert {:error, :enoent} =
               PackReader.open(@pack_34be9032_path, @pack_index_v2_34be9032_path <> "bogus")
    end

    test "error: index file is invalid (premature EOF)" do
      assert {:error, :invalid_index} =
               PackReader.open(@pack_34be9032_path, @pack_index_v2_34be9032_path <> "-partial")
    end

    test "error: index file is invalid (bad V1 fanout table)" do
      assert {:error, :invalid_index} =
               PackReader.open(@pack_34be9032_path, @pack_index_v1_34be9032_path <> "-bad-fanout")
    end

    test "error: index file is invalid (bad V2 fanout table)" do
      assert {:error, :invalid_index} =
               PackReader.open(@pack_34be9032_path, @pack_index_v2_34be9032_path <> "-bad-fanout")
    end

    test "error: index file is invalid (directory)" do
      assert {:error, :enoent} = PackReader.open(@pack_34be9032_path, "text/fixtures")
    end

    test "can open small pack with v1 index" do
      assert {:ok, %PackReader{idx_version: 1} = reader} =
               PackReader.open(@pack_34be9032_path, @pack_index_v1_34be9032_path)

      assert Enum.count(reader) == 8

      assert PackReader.has_object?(reader, "5b6e7c66c276e7610d4a73c70ec1a1f7c1003259")
      refute PackReader.has_object?(reader, "5b6e7c66c276e7610d4a73c70ec1a1f7c1004259")
      assert PackReader.has_object?(reader, "c59759f143fb1fe21c197981df75a7ee00290799")
      refute PackReader.has_object?(reader, "f59759f143fb1fe21c197981df75a7ee00290799")

      assert Enum.to_list(reader) == [
               %PackReaderEntry{
                 name: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
                 offset: 7782
               },
               %PackReaderEntry{
                 name: "540a36d136cf413e4b064c2b0e0a4db60f77feab",
                 offset: 339
               },
               %PackReaderEntry{
                 name: "5b6e7c66c276e7610d4a73c70ec1a1f7c1003259",
                 offset: 516
               },
               %PackReaderEntry{
                 name: "6ff87c4664981e4397625791c8ea3bbb5f2279a3",
                 offset: 556
               },
               %PackReaderEntry{
                 name: "82c6b885ff600be425b4ea96dee75dca255b69e7",
                 offset: 12
               },
               %PackReaderEntry{
                 name: "902d5476fa249b7abc9d84c611577a81381f0327",
                 offset: 7736
               },
               %PackReaderEntry{
                 name: "aabf2ffaec9b497f0950352b3e582d73035c2035",
                 offset: 470
               },
               %PackReaderEntry{
                 name: "c59759f143fb1fe21c197981df75a7ee00290799",
                 offset: 178
               }
             ]

      # Test halted enumeration case.

      assert reader
             |> Stream.take(2)
             |> Enum.to_list() == [
               %PackReaderEntry{
                 name: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
                 offset: 7782
               },
               %PackReaderEntry{
                 name: "540a36d136cf413e4b064c2b0e0a4db60f77feab",
                 offset: 339
               }
             ]
    end

    test "can open small pack with v2 index" do
      assert {:ok, %PackReader{idx_version: 2} = reader} =
               PackReader.open(@pack_34be9032_path, @pack_index_v2_34be9032_path)

      assert Enum.count(reader) == 8

      assert PackReader.has_object?(reader, "5b6e7c66c276e7610d4a73c70ec1a1f7c1003259")
      refute PackReader.has_object?(reader, "5b6e7c66c276e7610d4a73c70ec1a1f7c1004259")
      assert PackReader.has_object?(reader, "c59759f143fb1fe21c197981df75a7ee00290799")
      refute PackReader.has_object?(reader, "f59759f143fb1fe21c197981df75a7ee00290799")

      assert Enum.to_list(reader) == [
               %PackReaderEntry{
                 crc: 3_266_724_440,
                 name: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
                 offset: 7782
               },
               %PackReaderEntry{
                 crc: 1_923_962_818,
                 name: "540a36d136cf413e4b064c2b0e0a4db60f77feab",
                 offset: 339
               },
               %PackReaderEntry{
                 crc: 4_279_280_761,
                 name: "5b6e7c66c276e7610d4a73c70ec1a1f7c1003259",
                 offset: 516
               },
               %PackReaderEntry{
                 crc: 884_112_860,
                 name: "6ff87c4664981e4397625791c8ea3bbb5f2279a3",
                 offset: 556
               },
               %PackReaderEntry{
                 crc: 1_195_635_172,
                 name: "82c6b885ff600be425b4ea96dee75dca255b69e7",
                 offset: 12
               },
               %PackReaderEntry{
                 crc: 1_678_456_203,
                 name: "902d5476fa249b7abc9d84c611577a81381f0327",
                 offset: 7736
               },
               %PackReaderEntry{
                 crc: 706_202_462,
                 name: "aabf2ffaec9b497f0950352b3e582d73035c2035",
                 offset: 470
               },
               %PackReaderEntry{
                 crc: 188_439_462,
                 name: "c59759f143fb1fe21c197981df75a7ee00290799",
                 offset: 178
               }
             ]

      # Test halted enumeration case.

      assert reader
             |> Stream.take(2)
             |> Enum.to_list() == [
               %PackReaderEntry{
                 crc: 3_266_724_440,
                 name: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
                 offset: 7782
               },
               %PackReaderEntry{
                 crc: 1_923_962_818,
                 name: "540a36d136cf413e4b064c2b0e0a4db60f77feab",
                 offset: 339
               }
             ]
    end
  end

  describe "get_object/2" do
    setup do
      {:ok, %PackReader{idx_version: 2} = reader} =
        PackReader.open(@pack_34be9032_path, @pack_index_v2_34be9032_path)

      {:ok, reader: reader}
    end

    test "can read first object in pack", %{reader: reader} do
      assert {:ok,
              %Object{
                content: content,
                size: 245,
                id: "82c6b885ff600be425b4ea96dee75dca255b69e7",
                type: :commit
              }} = PackReader.get_object(reader, "82c6b885ff600be425b4ea96dee75dca255b69e7")

      rendered_content =
        content
        |> ContentSource.stream()
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      assert rendered_content ==
               ~S'''
               tree aabf2ffaec9b497f0950352b3e582d73035c2035
               parent c59759f143fb1fe21c197981df75a7ee00290799
               author Shawn O. Pearce <spearce@spearce.org> 1148676653 -0400
               committer Shawn O. Pearce <spearce@spearce.org> 1148676653 -0400

               Deleted Linus' header.
               '''
    end

    test "can read first blob in pack", %{reader: reader} do
      assert {:ok,
              %Object{
                content: content,
                size: 18787,
                id: "6ff87c4664981e4397625791c8ea3bbb5f2279a3",
                type: :blob
              }} = PackReader.get_object(reader, "6ff87c4664981e4397625791c8ea3bbb5f2279a3")

      rendered_content =
        content
        |> ContentSource.stream()
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      assert byte_size(rendered_content) == 18787

      assert String.starts_with?(rendered_content, "\n Note that the only")
      assert String.ends_with?(rendered_content, "nstead of this License.\n")
    end

    test "can read a delta-fied object from pack", %{reader: reader} do
      assert {:ok,
              %Object{
                content: content,
                size: 18009,
                id: "5b6e7c66c276e7610d4a73c70ec1a1f7c1003259",
                type: :blob
              }} = PackReader.get_object(reader, "5b6e7c66c276e7610d4a73c70ec1a1f7c1003259")

      rendered_content =
        content
        |> ContentSource.stream()
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      assert byte_size(rendered_content) == 18009

      assert String.starts_with?(rendered_content, "		    GNU")
      assert String.ends_with?(rendered_content, "nstead of this License.\n")
    end
  end
end
