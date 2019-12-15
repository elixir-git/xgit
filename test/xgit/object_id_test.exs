defmodule Xgit.ObjectIdTest do
  use ExUnit.Case, async: true

  alias Xgit.FileContentSource
  alias Xgit.ObjectId

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

  test "from_binary_iodata/1" do
    assert ObjectId.from_binary_iodata(
             <<18, 52, 86, 120, 144, 171, 205, 239, 18, 52, 18, 52, 86, 120, 144, 171, 205, 239,
               18, 52>>
           ) == "1234567890abcdef12341234567890abcdef1234"

    assert ObjectId.from_binary_iodata([
             18,
             52,
             86,
             120,
             144,
             171,
             205,
             239,
             18,
             52,
             18,
             52,
             86,
             120,
             144,
             171,
             205,
             239,
             18,
             52
           ]) == "1234567890abcdef12341234567890abcdef1234"

    assert_raise FunctionClauseError, fn ->
      ObjectId.from_binary_iodata([
        52,
        86,
        120,
        144,
        171,
        205,
        239,
        18,
        52,
        18,
        52,
        86,
        120,
        144,
        171,
        205,
        239,
        18,
        52
      ])

      # 19 bytes, not 20
    end
  end

  test "from_hex_charlist/1" do
    assert ObjectId.from_hex_charlist('1234567890abcdef12341234567890abcdef1234') ==
             {"1234567890abcdef12341234567890abcdef1234", []}

    assert ObjectId.from_hex_charlist('1234567890abcdef1231234567890abcdef1234') == false

    assert ObjectId.from_hex_charlist('1234567890abcdef123451234567890abcdef1234') ==
             {"1234567890abcdef123451234567890abcdef123", '4'}

    assert ObjectId.from_hex_charlist('1234567890abCdef12341234567890abcdef1234') == false

    assert ObjectId.from_hex_charlist('1234567890abXdef12341234567890abcdef1234') == false
  end

  test "to_binary_iodata/1" do
    assert ObjectId.to_binary_iodata("1234567890abcdef12341234567890abcdef1234") ==
             <<18, 52, 86, 120, 144, 171, 205, 239, 18, 52, 18, 52, 86, 120, 144, 171, 205, 239,
               18, 52>>
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
