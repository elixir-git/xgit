defmodule Xgit.Core.TreeTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Tree
  alias Xgit.Core.Tree.Entry

  @valid_entry %Entry{
    name: 'hello.txt',
    object_id: "7919e8900c3af541535472aebd56d44222b7b3a3",
    mode: 0o100644
  }

  @valid %Tree{
    entries: [@valid_entry]
  }

  describe "valid?/1" do
    test "happy path: valid entry" do
      assert Tree.valid?(@valid)
    end

    test "not a Tree struct" do
      refute Tree.valid?(%{})
      refute Tree.valid?("tree")
    end

    @invalid_mods [
      entries: [Map.put(@valid_entry, :name, "binary not allowed here")],
      entries: [Map.put(@valid_entry, :name, 'no/slashes')],
      entries: [42]
    ]

    test "invalid entries" do
      Enum.each(@invalid_mods, fn {key, value} ->
        invalid = Map.put(@valid, key, value)

        refute(
          Tree.valid?(invalid),
          "incorrectly accepted entry with :#{key} set to #{inspect(value)}"
        )
      end)
    end

    test "sorted (name)" do
      assert Tree.valid?(%Tree{
               entries: [
                 Map.put(@valid_entry, :name, 'abc'),
                 Map.put(@valid_entry, :name, 'abd'),
                 Map.put(@valid_entry, :name, 'abe')
               ]
             })
    end

    test "not sorted (name)" do
      refute Tree.valid?(%Tree{
               entries: [
                 Map.put(@valid_entry, :name, 'abc'),
                 Map.put(@valid_entry, :name, 'abf'),
                 Map.put(@valid_entry, :name, 'abe')
               ]
             })
    end
  end
end
