defmodule Xgit.Core.DirCacheTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.DirCache
  alias Xgit.Core.DirCache.Entry

  describe "empty/0" do
    assert %DirCache{version: 2, entry_count: 0, entries: []} = empty = DirCache.empty()
    assert DirCache.valid?(empty)
  end

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

  describe "valid?/1" do
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

  describe "add_entries/2" do
    test "happy path: sorting and adding to an empty list" do
      assert {:ok,
              %DirCache{
                version: 2,
                entry_count: 2,
                entries: [
                  %Entry{name: 'hello.txt', stage: 0},
                  %Entry{name: 'hello.txt', stage: 1}
                ]
              }} =
               DirCache.add_entries(DirCache.empty(), [
                 Map.put(@valid_entry, :stage, 1),
                 @valid_entry
               ])
    end

    test "happy path: sorting and merging into an existing list" do
      existing = %DirCache{
        version: 2,
        entry_count: 1,
        entries: [Map.put(@valid_entry, :stage, 1)]
      }

      assert DirCache.valid?(existing)

      assert {:ok,
              %DirCache{
                version: 2,
                entry_count: 3,
                entries: [
                  %Entry{name: 'hello.txt', stage: 0},
                  %Entry{name: 'hello.txt', stage: 1},
                  %Entry{name: 'hello.txt', stage: 2}
                ]
              }} =
               DirCache.add_entries(existing, [
                 Map.put(@valid_entry, :stage, 2),
                 @valid_entry
               ])
    end

    test "happy path: replacing an existing item" do
      existing = %DirCache{
        version: 2,
        entry_count: 1,
        entries: [%{@valid_entry | stage: 1, size: 43}]
      }

      assert DirCache.valid?(existing)

      assert {:ok,
              %DirCache{
                version: 2,
                entry_count: 2,
                entries: [
                  %Entry{name: 'hello.txt', stage: 0},
                  %Entry{name: 'hello.txt', stage: 1, size: 495}
                ]
              }} =
               DirCache.add_entries(existing, [
                 %{@valid_entry | stage: 1, size: 495},
                 @valid_entry
               ])
    end

    test "{:error, :invalid_dir_cache}" do
      assert {:error, :invalid_dir_cache} =
               DirCache.add_entries(Map.put(@valid, :entry_count, 999), [@valid_entry])
    end

    test "{:error, :invalid_entries}" do
      assert {:error, :invalid_entries} =
               DirCache.add_entries(DirCache.empty(), [Map.put(@valid_entry, :name, '')])
    end

    test "{:error, :duplicate_entries}" do
      assert {:error, :duplicate_entries} =
               DirCache.add_entries(DirCache.empty(), [
                 @valid_entry,
                 Map.put(@valid_entry, :name, 'other'),
                 @valid_entry
               ])
    end

    test "FunctionClauseError: not a DirCache" do
      assert_raise FunctionClauseError, fn ->
        DirCache.add_entries("trust me, it's a DirCache", [@valid_entry])
      end
    end

    test "FunctionClauseError: not a list of entries" do
      assert_raise FunctionClauseError, fn ->
        DirCache.add_entries(DirCache.empty(), @valid_entry)
      end
    end
  end

  describe "remove_entries/2" do
    test "happy path: removing from an empty list" do
      assert {:ok,
              %DirCache{
                version: 2,
                entry_count: 0,
                entries: []
              }} = DirCache.remove_entries(DirCache.empty(), [{'hello.txt', 0}])
    end

    test "happy path: removing something that doesn't exist from a non-empty list" do
      assert {:ok, @valid} = DirCache.remove_entries(@valid, [{'goodbye.txt', 0}])
    end

    test "happy path: ignores mismatch on stage" do
      assert {:ok, @valid} = DirCache.remove_entries(@valid, [{'hello.txt', 1}])
    end

    test "happy path: removes only item in list" do
      assert {:ok,
              %DirCache{
                version: 2,
                entry_count: 0,
                entries: []
              }} = DirCache.remove_entries(@valid, [{'hello.txt', 0}])
    end

    test "happy path: removes all matching entries via stage :all" do
      assert {:ok,
              %DirCache{
                version: 2,
                entry_count: 0,
                entries: []
              }} =
               DirCache.remove_entries(
                 %DirCache{
                   version: 2,
                   entry_count: 3,
                   entries: [
                     Map.put(@valid_entry, :stage, 0),
                     Map.put(@valid_entry, :stage, 1),
                     Map.put(@valid_entry, :stage, 3)
                   ]
                 },
                 [{'hello.txt', :all}]
               )
    end

    test "happy path: removes only matching entries via name" do
      assert {:ok, @valid} =
               DirCache.remove_entries(
                 %DirCache{
                   version: 2,
                   entry_count: 2,
                   entries: [Map.put(@valid_entry, :name, 'abc.txt'), @valid_entry]
                 },
                 [{'abc.txt', 0}]
               )
    end

    test "happy path: sorts list of items to remove" do
      assert {:ok, @valid} =
               DirCache.remove_entries(
                 %DirCache{
                   version: 2,
                   entry_count: 3,
                   entries: [
                     @valid_entry,
                     Map.put(@valid_entry, :name, 'other.txt'),
                     Map.put(@valid_entry, :name, 'xgit.txt')
                   ]
                 },
                 [{'xgit.txt', 0}, {'other.txt', 0}]
               )
    end

    test "{:error, :invalid_dir_cache}" do
      assert {:error, :invalid_dir_cache} =
               DirCache.remove_entries(Map.put(@valid, :entry_count, 999), [
                 {'xgit.txt', 0},
                 {'other.txt', 0}
               ])
    end

    test "{:error, :invalid_entries}" do
      assert {:error, :invalid_entries} =
               DirCache.remove_entries(DirCache.empty(), [{'hello.txt', 7}])
    end

    test "FunctionClauseError: not a DirCache" do
      assert_raise FunctionClauseError, fn ->
        DirCache.remove_entries("trust me, it's a DirCache", [{'hello.txt', 0}])
      end
    end

    test "FunctionClauseError: not a list of entries" do
      assert_raise FunctionClauseError, fn ->
        DirCache.remove_entries(DirCache.empty(), {'hello.txt', 0})
      end
    end
  end
end
