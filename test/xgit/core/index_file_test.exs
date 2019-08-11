defmodule Xgit.Core.IndexFileTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Core.IndexFile

  describe "from_stream/2" do
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
               |> File.open!()
               |> IndexFile.from_iodevice()

      assert index_file = %IndexFile{
               entries: [
                 %IndexFile.Entry{
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
                 %IndexFile.Entry{
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
  end
end
