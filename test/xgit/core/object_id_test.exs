defmodule Xgit.Core.ObjectIdTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.FileContentSource
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

  describe "calculate_id/3" do
    test "happy path: SHA hash with string content" do
      assert ObjectId.calculate_id("test content\n", :blob) ==
               "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
    end

    test "happy path: deriving SHA hash from file on disk" do
      Temp.track!()
      path = Temp.path!()

      content =
        1..1000
        |> Enum.map(fn _ -> "foobar" end)
        |> Enum.join()

      File.write!(path, content)

      {output, 0} = System.cmd("git", ["hash-object", path])
      expected_object_id = String.trim(output)

      fcs = FileContentSource.new(path)
      assert ObjectId.calculate_id(fcs, :blob) == expected_object_id
    end

    test "error: content nil" do
      assert_raise FunctionClauseError, fn ->
        ObjectId.calculate_id(nil, :blob)
      end
    end

    test "error: :type invalid" do
      assert_raise FunctionClauseError, fn ->
        ObjectId.calculate_id("test content\n", :bogus)
      end
    end
  end
end
