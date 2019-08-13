defmodule Xgit.Core.DirCache.EntryTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.DirCache.Entry

  @valid %Entry{
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

  describe "valid?/1" do
    test "happy path: valid entry" do
      assert Entry.valid?(@valid)
    end

    @invalid_mods [
      name: "binary, not byte list",
      name: '',
      name: '/absolute/path',
      stage: 4,
      object_id: "7919e8900c3af541535472aebd56d44222b7b3a",
      object_id: "7919e8900c3af541535472aebd56d44222b7b3a34",
      object_id: "0000000000000000000000000000000000000000",
      mode: 0,
      mode: 0o100645,
      size: -1,
      ctime: 1.45,
      ctime_ns: -1,
      mtime: "recently",
      mtime_ns: true,
      dev: 4.2,
      ino: true,
      uid: "that guy",
      gid: "those people",
      assume_valid?: "yes",
      extended?: "no",
      skip_worktree?: :maybe,
      intent_to_add?: :why_not?
    ]

    test "invalid entries" do
      Enum.each(@invalid_mods, fn {key, value} ->
        invalid = Map.put(@valid, key, value)

        refute(
          Entry.valid?(invalid),
          "incorrectly accepted entry with :#{key} set to #{inspect(value)}"
        )
      end)
    end
  end

  describe "compare/2" do
    test "special case: nil sorts first" do
      assert Entry.compare(nil, @valid) == :lt
    end

    test "equality" do
      assert Entry.compare(@valid, @valid) == :eq
    end

    @name_gt Map.put(@valid, :name, 'later.txt')
    test "comparison based on name" do
      assert Entry.compare(@valid, @name_gt) == :lt
      assert Entry.compare(@name_gt, @valid) == :gt
    end

    @mode_gt Map.put(@valid, :mode, 0o100755)
    test "comparison based on mode" do
      assert Entry.compare(@valid, @mode_gt) == :lt
      assert Entry.compare(@mode_gt, @valid) == :gt
    end

    @stage_gt Map.put(@valid, :stage, 2)
    test "comparison based on stage" do
      assert Entry.compare(@valid, @stage_gt) == :lt
      assert Entry.compare(@stage_gt, @valid) == :gt
    end
  end
end
