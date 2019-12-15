defmodule Xgit.DirCache.FromIoDeviceTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.DirCache
  alias Xgit.Test.TempDirTestCase
  alias Xgit.Util.TrailingHashDevice

  import ExUnit.CaptureLog

  describe "from_iodevice/1" do
    test "happy path: can read from command-line git (empty index)", %{ref: ref} do
      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--add",
            "--cacheinfo",
            "100644",
            "18832d35117ef2f013c4009f5b2128dfaeff354f",
            "hello.txt"
          ],
          cd: ref
        )

      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--remove",
            "test_content.txt"
          ],
          cd: ref
        )

      assert {:ok, index_file} =
               [ref, ".git", "index"]
               |> Path.join()
               |> thd_open_file!()
               |> DirCache.from_iodevice()

      assert index_file = %DirCache{
               entries: [],
               entry_count: 0,
               version: 2
             }
    end

    test "happy path: can read from command-line git (two small files)", %{ref: ref} do
      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--add",
            "--cacheinfo",
            "100644",
            "18832d35117ef2f013c4009f5b2128dfaeff354f",
            "hello.txt"
          ],
          cd: ref
        )

      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--add",
            "--cacheinfo",
            "100644",
            "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
            "test_content.txt"
          ],
          cd: ref
        )

      assert {:ok, index_file} =
               [ref, ".git", "index"]
               |> Path.join()
               |> thd_open_file!()
               |> DirCache.from_iodevice()

      assert index_file = %DirCache{
               entries: [
                 %DirCache.Entry{
                   assume_valid?: false,
                   ctime: 0,
                   ctime_ns: 0,
                   dev: 0,
                   extended?: false,
                   gid: 0,
                   ino: 0,
                   intent_to_add?: false,
                   mode: 0o100644,
                   mtime: 0,
                   mtime_ns: 0,
                   name: 'hello.txt',
                   object_id: "18832d35117ef2f013c4009f5b2128dfaeff354f",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 },
                 %DirCache.Entry{
                   assume_valid?: false,
                   ctime: 0,
                   ctime_ns: 0,
                   dev: 0,
                   extended?: false,
                   gid: 0,
                   ino: 0,
                   intent_to_add?: false,
                   mode: 0o100644,
                   mtime: 0,
                   mtime_ns: 0,
                   name: 'test_content.txt',
                   object_id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 }
               ],
               entry_count: 2,
               version: 2
             }
    end

    @names [
      "a",
      "ab",
      "abc",
      "abcd",
      "abcde",
      "abcdef",
      "abcdefg",
      "abcdefgh",
      "ajaksldfjkadsfkasdfalsdjfklasdjf"
    ]

    test "happy path: can read from command-line git (varying name lengths)" do
      Enum.each(@names, fn name ->
        %{tmp_dir: tmp} = TempDirTestCase.tmp_dir!()

        {_output, 0} =
          System.cmd(
            "git",
            ["init"],
            cd: tmp
          )

        {_output, 0} =
          System.cmd(
            "git",
            [
              "update-index",
              "--add",
              "--cacheinfo",
              "100644",
              "18832d35117ef2f013c4009f5b2128dfaeff354f",
              name
            ],
            cd: tmp
          )

        assert {:ok, index_file} =
                 [tmp, ".git", "index"]
                 |> Path.join()
                 |> thd_open_file!()
                 |> DirCache.from_iodevice()

        assert index_file = %DirCache{
                 entries: [
                   %DirCache.Entry{
                     assume_valid?: false,
                     ctime: 0,
                     ctime_ns: 0,
                     dev: 0,
                     extended?: false,
                     gid: 0,
                     ino: 0,
                     intent_to_add?: false,
                     mode: 0o100644,
                     mtime: 0,
                     mtime_ns: 0,
                     name: :binary.bin_to_list(name),
                     object_id: "18832d35117ef2f013c4009f5b2128dfaeff354f",
                     size: 0,
                     skip_worktree?: false,
                     stage: 0,
                     uid: 0
                   }
                 ],
                 entry_count: 1,
                 version: 2
               }
      end)
    end
  end

  test "happy path: can skip TREE data structure" do
    Enum.each(@names, fn name ->
      %{tmp_dir: tmp} = TempDirTestCase.tmp_dir!()

      {_output, 0} =
        System.cmd(
          "git",
          ["init"],
          cd: tmp
        )

      {_output, 0} =
        System.cmd(
          "git",
          [
            "update-index",
            "--add",
            "--cacheinfo",
            "100644",
            "18832d35117ef2f013c4009f5b2128dfaeff354f",
            name
          ],
          cd: tmp
        )

      # Calling `git write-tree` causes git to add a `TREE` extension into the index file.
      # Test that we know how to read that and skip it.

      {_output, 0} =
        System.cmd(
          "git",
          ["write-tree", "--missing-ok"],
          cd: tmp
        )

      assert capture_log(fn ->
               assert {:ok, index_file} =
                        [tmp, ".git", "index"]
                        |> Path.join()
                        |> thd_open_file!()
                        |> DirCache.from_iodevice()
             end) =~ ~s(skipping extension with signature "TREE", 25 bytes)

      assert index_file = %DirCache{
               entries: [
                 %DirCache.Entry{
                   assume_valid?: false,
                   ctime: 0,
                   ctime_ns: 0,
                   dev: 0,
                   extended?: false,
                   gid: 0,
                   ino: 0,
                   intent_to_add?: false,
                   mode: 0o100644,
                   mtime: 0,
                   mtime_ns: 0,
                   name: :binary.bin_to_list(name),
                   object_id: "18832d35117ef2f013c4009f5b2128dfaeff354f",
                   size: 0,
                   skip_worktree?: false,
                   stage: 0,
                   uid: 0
                 }
               ],
               entry_count: 1,
               version: 2
             }
    end)
  end

  test "error: iodevice isn't a TrailingHashDevice" do
    {:ok, pid} = GenServer.start_link(NotValid, nil)
    assert {:error, :not_sha_hash_device} = DirCache.from_iodevice(pid)
  end

  test "error: file doesn't start with DIRC signature" do
    assert {:error, :invalid_format} = parse_iodata_as_index_file('DIRX')
  end

  test "error: unsupported version" do
    assert {:error, :unsupported_version} = parse_iodata_as_index_file(['DIRC', 0, 0, 0, 1])
  end

  test "error: incomplete # entries" do
    assert {:error, :invalid_format} = parse_iodata_as_index_file(['DIRC', 0, 0, 0, 2, 0, 0])
  end

  test "error: too many entries" do
    assert {:error, :too_many_entries} =
             parse_iodata_as_index_file(['DIRC', 0, 0, 0, 2, 1, 1, 1, 1])
  end

  test "error: missing entries" do
    assert {:error, :invalid_format} = parse_iodata_as_index_file(v2_header_with_n_entries(1))
  end

  test "error: partial entry" do
    assert {:error, :invalid_format} =
             parse_iodata_as_index_file([v2_header_with_n_entries(1), 0, 0])
  end

  test "error: invalid file mode" do
    # 129, 165 = 0o100645 (invalid)
    assert {:error, :invalid_format} =
             parse_iodata_as_index_file([v2_header_with_valid_entry_through_ino(), 0, 0, 129, 165])
  end

  test "error: missing object ID" do
    assert {:error, :invalid_format} =
             parse_iodata_as_index_file(v2_header_with_valid_entry_through_file_size())
  end

  test "error: partial object ID" do
    assert {:error, :invalid_format} =
             parse_iodata_as_index_file([
               v2_header_with_valid_entry_through_file_size(),
               [0, 1, 2, 3, 4]
             ])
  end

  test "error: null object ID" do
    assert {:error, :invalid_format} =
             parse_iodata_as_index_file([
               v2_header_with_valid_entry_through_file_size(),
               Enum.map(1..20, fn _ -> 0 end),
               [0, 9],
               'hello.txt',
               0
             ])
  end

  test "error: incomplete flags / name size" do
    assert {:error, :invalid_format} =
             parse_iodata_as_index_file([
               v2_header_with_valid_entry_through_file_size(),
               Enum.map(1..20, fn n -> n end),
               0
             ])
  end

  test "error: incomplete name" do
    assert {:error, :invalid_format} =
             parse_iodata_as_index_file([
               v2_header_with_valid_entry_through_file_size(),
               Enum.map(1..20, fn n -> n end),
               [0, 9],
               'hello'
             ])
  end

  test "error: name missing trailing null" do
    assert {:error, :invalid_format} =
             parse_iodata_as_index_file([
               v2_header_with_valid_entry_through_file_size(),
               Enum.map(1..20, fn n -> n end),
               [0, 9],
               'hello.txt'
             ])
  end

  test "error: name too long" do
    assert {:error, :invalid_format} =
             parse_iodata_as_index_file([
               v2_header_with_valid_entry_through_file_size(),
               Enum.map(1..20, fn n -> n end),
               [15, 255],
               'hello.txt'
             ])
  end

  test "error: required extensions not supported" do
    assert capture_log(fn ->
             assert {:error, :unsupported_extension} =
                      parse_iodata_as_index_file([
                        v2_header_with_valid_entry_through_file_size(),
                        Enum.map(1..20, fn n -> n end),
                        [0, 9],
                        'hello.txt',
                        0,
                        'abcd',
                        0,
                        0,
                        0,
                        25
                      ])
           end) =~ ~s(don't know how to read required extension with signature "abcd", 25 bytes)
  end

  test "error: incorrect SHA-1 hash" do
    assert {:error, :sha_hash_mismatch} =
             parse_corrupt_iodata_as_index_file([
               v2_header_with_valid_entry_through_file_size(),
               Enum.map(1..20, fn n -> n end),
               [0, 9],
               'hello.txt',
               0
             ])
  end

  defp parse_iodata_as_index_file(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> thd_open_string!()
    |> DirCache.from_iodevice()
  end

  defp parse_corrupt_iodata_as_index_file(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> thd_open_corrupt_string!()
    |> DirCache.from_iodevice()
  end

  defp thd_open_file!(path) do
    {:ok, iodevice} = TrailingHashDevice.open_file(path)
    iodevice
  end

  defp thd_open_string!(s) do
    {:ok, iodevice} = TrailingHashDevice.open_string(s <> hash_for_string(s))
    iodevice
  end

  defp thd_open_corrupt_string!(s) do
    {:ok, iodevice} = TrailingHashDevice.open_string(s <> "bogusbogusbogusbogus")
    iodevice
  end

  defp hash_for_string(s) do
    :sha
    |> :crypto.hash_init()
    |> :crypto.hash_update(s)
    |> :crypto.hash_final()
  end

  defp v2_header_with_n_entries(n) when n > 0 and n <= 255, do: ['DIRC', 0, 0, 0, 2, 0, 0, 0, n]

  defp v2_header_with_valid_entry_through_ino,
    do: [v2_header_with_n_entries(1), Enum.map(1..24, fn _ -> 0 end)]

  defp v2_header_with_valid_entry_through_file_size,
    do: [
      v2_header_with_valid_entry_through_ino(),
      [0, 0, 129, 164],
      Enum.map(1..11, fn _ -> 0 end),
      14
    ]
end
