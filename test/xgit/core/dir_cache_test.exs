defmodule Xgit.Core.DirCacheTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry

  describe "empty/0" do
    assert %DirCache{version: 2, entry_count: 0, entries: []} = empty = DirCache.empty()
    assert DirCache.valid?(empty)
  end

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

    test "sorted (name)" do
      assert DirCache.valid?(%DirCache{
               version: 2,
               entry_count: 3,
               entries: [
                 Map.put(@valid_entry, :name, 'abc'),
                 Map.put(@valid_entry, :name, 'abd'),
                 Map.put(@valid_entry, :name, 'abe')
               ]
             })
    end

    test "sorted (stage)" do
      assert DirCache.valid?(%DirCache{
               version: 2,
               entry_count: 3,
               entries: [
                 Map.put(@valid_entry, :stage, 0),
                 Map.put(@valid_entry, :stage, 1),
                 Map.put(@valid_entry, :stage, 3)
               ]
             })
    end

    test "not sorted (name)" do
      refute DirCache.valid?(%DirCache{
               version: 2,
               entry_count: 3,
               entries: [
                 Map.put(@valid_entry, :name, 'abc'),
                 Map.put(@valid_entry, :name, 'abf'),
                 Map.put(@valid_entry, :name, 'abe')
               ]
             })
    end

    test "not sorted (stage)" do
      refute DirCache.valid?(%{
               version: 2,
               entry_count: 3,
               entries: [
                 Map.put(@valid_entry, :stage, 0),
                 Map.put(@valid_entry, :stage, 3),
                 Map.put(@valid_entry, :stage, 2)
               ]
             })
    end
  end
end
