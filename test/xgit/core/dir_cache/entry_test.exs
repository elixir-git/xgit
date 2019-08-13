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
