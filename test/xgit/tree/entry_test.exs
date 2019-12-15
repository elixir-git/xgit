defmodule Xgit.Tree.EntryTest do
  use ExUnit.Case, async: true

  alias Xgit.Tree.Entry

  @valid %Entry{
    name: 'hello.txt',
    object_id: "7919e8900c3af541535472aebd56d44222b7b3a3",
    mode: 0o100644
  }

  describe "valid?/1" do
    test "happy path: valid entry" do
      assert Entry.valid?(@valid)
    end

    @invalid_mods [
      name: "binary, not byte list",
      name: '',
      name: '/absolute/path',
      object_id: "7919e8900c3af541535472aebd56d44222b7b3a",
      object_id: "7919e8900c3af541535472aebd56d44222b7b3a34",
      object_id: "0000000000000000000000000000000000000000",
      mode: 0,
      mode: 0o100645
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
    test "doesn't compare based on mode" do
      assert Entry.compare(@valid, @mode_gt) == :eq
      assert Entry.compare(@mode_gt, @valid) == :eq
    end
  end
end
