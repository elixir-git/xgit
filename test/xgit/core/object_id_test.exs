defmodule Xgit.Core.ObjectIdTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.ObjectId

  test "zero/0" do
    zero = ObjectId.zero()
    assert is_binary(zero)
    assert String.length(zero) == 40
    assert ObjectId.valid?(zero)
    assert String.match?(zero, ~r/^0+$/)
  end

  test "valid?/1" do
    assert ObjectId.valid?("1234567890abcdef12341234567890abcdef1234")
    refute ObjectId.valid?("1234567890abcdef1231234567890abcdef1234")
    refute ObjectId.valid?("1234567890abcdef123451234567890abcdef1234")
    refute ObjectId.valid?("1234567890abCdef12341234567890abcdef1234")
    refute ObjectId.valid?("1234567890abXdef12341234567890abcdef1234")

    refute ObjectId.valid?(nil)
  end
end
