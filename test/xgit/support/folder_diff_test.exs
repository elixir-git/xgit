defmodule FolderDiffTest do
  use ExUnit.Case

  # credo:disable-for-this-file Credo.Check.Readability.RedundantBlankLines
  # Some quoted strings have multiple blank lines and latest Credo doesn't like that.

  import FolderDiff

  setup do
    Temp.track!()
    :ok
  end

  test "happy path" do
    t = Temp.mkdir!()

    t
    |> Path.join("HEAD")
    |> File.write!("ref: refs/heads/master\n")

    t
    |> Path.join("hooks")
    |> File.mkdir_p!()

    assert_folders_are_equal(t, t)
  end

  test "failure: file missing on one side" do
    f1 = Temp.mkdir!()

    f1
    |> Path.join("HEAD")
    |> File.write!("ref: refs/heads/master\n")

    f1
    |> Path.join("hooks")
    |> File.mkdir_p!()

    f2 = Temp.mkdir!()

    f2
    |> Path.join("hooks")
    |> File.mkdir_p!()

    try do
      assert_folders_are_equal(f1, f2)
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message == "File HEAD exists in folder #{f1}, but is missing in #{f2}"
    end

    try do
      assert_folders_are_equal(f2, f1)
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message == "File HEAD exists in folder #{f1}, but is missing in #{f2}"
    end
  end

  test "failure: last file (sorted) missing on one side" do
    f1 = Temp.mkdir!()

    f1
    |> Path.join("HEAD")
    |> File.write!("ref: refs/heads/master\n")

    f1
    |> Path.join("Books")
    |> File.mkdir_p!()

    f2 = Temp.mkdir!()

    f2
    |> Path.join("Books")
    |> File.mkdir_p!()

    try do
      assert_folders_are_equal(f1, f2)
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message == "File HEAD exists in folder #{f1}, but is missing in #{f2}"
    end

    try do
      assert_folders_are_equal(f2, f1)
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message == "File HEAD exists in folder #{f1}, but is missing in #{f2}"
    end
  end

  test "failure: files mismatch" do
    f1 = Temp.mkdir!()

    f1
    |> Path.join("HEAD")
    |> File.write!("ref: refs/heads/master\n")

    f1
    |> Path.join("hooks")
    |> File.mkdir_p!()

    f2 = Temp.mkdir!()

    f2
    |> Path.join("HEAD")
    |> File.write!("ref: refs/heads/mumble\n")

    f2
    |> Path.join("hooks")
    |> File.mkdir_p!()

    try do
      assert_folders_are_equal(f1, f2)
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message == ~s"""
               Files mismatch:

               #{f1}/HEAD:
               ref: refs/heads/master


               #{f2}/HEAD:
               ref: refs/heads/mumble


               """
    end

    try do
      assert_folders_are_equal(f2, f1)
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message == ~s"""
               Files mismatch:

               #{f2}/HEAD:
               ref: refs/heads/mumble


               #{f1}/HEAD:
               ref: refs/heads/master


               """
    end
  end

  test "failure: binary files mismatch" do
    f1 = Temp.mkdir!()

    f1
    |> Path.join("HEAD")
    |> File.write!([
      120,
      1,
      75,
      202,
      201,
      79,
      82,
      48,
      52,
      102,
      40,
      73,
      45,
      46,
      81,
      72,
      206,
      207,
      43,
      73,
      205,
      43,
      225,
      2,
      0,
      75,
      223,
      7,
      9
    ])

    f2 = Temp.mkdir!()

    f2
    |> Path.join("HEAD")
    |> File.write!([
      120,
      156,
      75,
      202,
      201,
      79,
      82,
      48,
      52,
      102,
      40,
      73,
      45,
      46,
      81,
      72,
      206,
      207,
      43,
      73,
      205,
      43,
      225,
      2,
      0,
      75,
      223,
      7,
      9
    ])

    try do
      assert_folders_are_equal(f1, f2)
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message == ~s"""
               Files mismatch:

               #{f1}/HEAD:
               [120, 1, 75, 202, 201, 79, 82, 48, 52, 102, 40, 73, 45, 46, 81, 72, 206, 207, 43, 73, 205, 43, 225, 2, 0, 75, 223, 7, 9]

               #{f2}/HEAD:
               [120, 156, 75, 202, 201, 79, 82, 48, 52, 102, 40, 73, 45, 46, 81, 72, 206, 207, 43, 73, 205, 43, 225, 2, 0, 75, 223, 7, 9]

               """
    end

    try do
      assert_folders_are_equal(f2, f1)
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message == ~s"""
               Files mismatch:

               #{f2}/HEAD:
               [120, 156, 75, 202, 201, 79, 82, 48, 52, 102, 40, 73, 45, 46, 81, 72, 206, 207, 43, 73, 205, 43, 225, 2, 0, 75, 223, 7, 9]

               #{f1}/HEAD:
               [120, 1, 75, 202, 201, 79, 82, 48, 52, 102, 40, 73, 45, 46, 81, 72, 206, 207, 43, 73, 205, 43, 225, 2, 0, 75, 223, 7, 9]

               """
    end
  end

  test "failure: truncated long string" do
    f1 = Temp.mkdir!()

    f1
    |> Path.join("HEAD")
    |> File.write!(~s"""
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    12345678901234567890123456789012345678901234567890
    """)

    f1
    |> Path.join("hooks")
    |> File.mkdir_p!()

    f2 = Temp.mkdir!()

    f2
    |> Path.join("HEAD")
    |> File.write!("ref: refs/heads/mumble\n")

    f2
    |> Path.join("hooks")
    |> File.mkdir_p!()

    try do
      assert_folders_are_equal(f1, f2)
    rescue
      error in [ExUnit.AssertionError] ->
        assert error.message == ~s"""
               Files mismatch:

               #{f1}/HEAD:
               561 bytes starting with:
               12345678901234567890123456789012345678901234567890
               12345678901234567890123456789012345678901234567890
               12345678901234567890123456789012345678901234567890
               12345678901234567890123456789012345678901234567890
               12345678901234567890123456789012345678901234567890
               12345678901234567890123456789012345678901234567890
               12345678901234567890123456789012345678901234567890
               12345678901234567890123456789012345678901234567890
               12345678901234567890123456789012345678901234567890
               12345678901234567890123456789012345678901


               #{f2}/HEAD:
               ref: refs/heads/mumble


               """
    end
  end
end
