defmodule Xgit.Plumbing.ObjectTypeTest do
  use ExUnit.Case, async: true
  use Xgit.Plumbing.ObjectType

  @object_types [:blob, :tree, :commit, :tag]

  defp accepted_object_type?(t) when is_object_type(t), do: true
  defp accepted_object_type?(_), do: false

  describe "is_object_type/1" do
    test "accepts known object types" do
      for t <- @object_types do
        assert accepted_object_type?(t)
      end
    end

    test "rejects invalid values" do
      refute accepted_object_type?(:mumble)
      refute accepted_object_type?(1)
      refute accepted_object_type?("blob")
      refute accepted_object_type?('blob')
      refute accepted_object_type?(%{blob: true})
      refute accepted_object_type?({:blob})
      refute accepted_object_type?(fn -> :blob end)
      refute accepted_object_type?(self())
    end
  end
end
