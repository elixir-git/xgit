defmodule Xgit.ObjectTypeTest do
  use ExUnit.Case, async: true
  use Xgit.ObjectType

  @valid_object_types [:blob, :tree, :commit, :tag]
  @invalid_object_types [:mumble, 1, "blob", 'blob', %{blob: true}, {:blob}, self()]

  defp accepted_object_type?(t) when is_object_type(t), do: true
  defp accepted_object_type?(_), do: false

  describe "valid?/1" do
    test "accepts known object types" do
      for t <- @valid_object_types do
        assert ObjectType.valid?(t)
      end
    end

    test "rejects invalid values" do
      for t <- @invalid_object_types do
        refute ObjectType.valid?(t)
      end
    end
  end

  describe "is_object_type/1" do
    test "accepts known object types" do
      for t <- @valid_object_types do
        assert accepted_object_type?(t)
      end
    end

    test "rejects invalid values" do
      for t <- @invalid_object_types do
        refute accepted_object_type?(t)
      end
    end
  end

  describe "from_bytelist/1" do
    test "accepts known object types" do
      for t <- @valid_object_types do
        assert t = ObjectType.from_bytelist('#{t}')
      end
    end

    test "returns :error for other atoms" do
      assert :error = ObjectType.from_bytelist('commitx')
    end

    test "FunctionClauseError if not bytelist" do
      assert_raise FunctionClauseError,
                   fn ->
                     ObjectType.from_bytelist("commit")
                   end
    end
  end
end
