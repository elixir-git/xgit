defmodule Xgit.Core.DirCacheTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry

  describe "valid?/1" do
    @valid_entry %Entry{
      name: 'hello.txt',
      stage: 0,
      object_id: "7919e8900c3af541535472aebd56d44222b7b3a3",
      mode: 0o100644,
      size: 42,
      ctime: 1_565_612_933,
      ctime_ns: 0,
      mtime: 1_565_612_941,
      mtime_ns: 0,
      dev: 0,
      ino: 0,
      uid: 0,
      gid: 0,
      assume_valid?: true,
      extended?: false,
      skip_worktree?: true,
      intent_to_add?: false
    }

    @valid %DirCache{
      version: 2,
      entry_count: 1,
      entries: [@valid_entry]
    }

    test "happy path: valid entry" do
      assert DirCache.valid?(@valid)
    end

    @invalid_mods [
      version: 1,
      version: "current",
      entry_count: 4924,
      entries: [Map.put(@valid_entry, :stage, 4)]
    ]

    test "invalid entries" do
      Enum.each(@invalid_mods, fn {key, value} ->
        invalid = Map.put(@valid, key, value)

        refute(
          DirCache.valid?(invalid),
          "incorrectly accepted entry with :#{key} set to #{inspect(value)}"
        )
      end)
    end
  end
end
