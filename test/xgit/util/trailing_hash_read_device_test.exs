defmodule Xgit.Util.TrailingHashReadDeviceTest do
  use ExUnit.Case, async: true

  alias Xgit.Util.TrailingHashReadDevice, as: THR

  import ExUnit.CaptureLog

  describe "test infrastructure" do
    test "string_with_trailing_hash/1" do
      s = string_with_trailing_hash("hello")

      assert byte_size(s) == 25

      assert s ==
               "hello" <>
                 <<170, 244, 198, 29, 220, 197, 232, 162, 218, 190, 222, 15, 59, 72, 44, 217, 174,
                   169, 67, 77>>
    end
  end

  describe "open_file/1" do
    test "simple file" do
      assert {:ok, device} = open_file_with_trailing_hash("hello")

      assert "hello" = IO.binread(device, 5)
      assert :eof = IO.binread(device, 5)

      assert THR.valid_hash?(device)
    end

    test "multiple reads" do
      assert {:ok, device} = open_file_with_trailing_hash("hello, goodbye")

      assert "hello" = IO.binread(device, 5)
      assert ", " = IO.binread(device, 2)
      assert "goodbye" = IO.binread(device, 7)
      assert :eof = IO.binread(device, 1)

      assert THR.valid_hash?(device)
    end

    test "immediate EOF if file is <= 20 bytes long" do
      Temp.track!()
      path = Temp.path!()

      File.write!(path, "hello")

      assert {:ok, device} = THR.open_file(path)
      assert is_pid(device)

      assert :eof = IO.binread(device, 5)

      refute THR.valid_hash?(device)
    end

    test "hash is invalid" do
      Temp.track!()
      path = Temp.path!()

      File.write!(path, "hellobogusbogusbogusbogus")

      assert {:ok, device} = THR.open_file(path)
      assert is_pid(device)

      assert "hello" = IO.binread(device, 5)
      assert :eof = IO.binread(device, 5)

      refute THR.valid_hash?(device)
    end

    test "Posix error" do
      Temp.track!()
      path = Temp.path!()
      File.mkdir_p!(path)

      assert {:error, :eisdir} = THR.open_file(path)
    end

    test "error :too_soon" do
      assert {:ok, device} = open_file_with_trailing_hash("hello, goodbye")

      assert "hello" = IO.binread(device, 5)
      assert THR.valid_hash?(device) == :too_soon
    end

    test "error :already_called" do
      assert {:ok, device} = open_file_with_trailing_hash("hello")

      assert "hello" = IO.binread(device, 5)
      assert :eof = IO.binread(device, 5)

      assert THR.valid_hash?(device)
      assert THR.valid_hash?(device) == :already_called
    end

    test "error: unexpected io request" do
      assert {:ok, device} = open_file_with_trailing_hash("hello")

      assert capture_log(fn ->
               assert {:error, :request} = IO.binwrite(device, "hello")
             end) =~
               ~s(TrailingHashReadDevice received unexpected iorequest {:put_chars, :latin1, "hello"})
    end

    test "warn: unexpected message" do
      assert {:ok, device} = open_file_with_trailing_hash("hello, goodbye")

      assert capture_log(fn ->
               send(device, :random_unknown_message)
             end) =~ "TrailingHashReadDevice received unexpected message :random_unknown_message"
    end

    test "warn: unexpected call" do
      assert {:ok, device} = open_file_with_trailing_hash("hello, goodbye")

      assert capture_log(fn ->
               assert :unknown_message = GenServer.call(device, :random_unknown_call)
             end) =~ "TrailingHashReadDevice received unexpected call :random_unknown_call"
    end
  end

  describe "open_string/1" do
    test "simple file" do
      assert {:ok, device} = open_string_with_trailing_hash("hello")

      assert "hello" = IO.binread(device, 5)
      assert :eof = IO.binread(device, 5)

      assert THR.valid_hash?(device)
    end

    test "FunctionClauseError if string is <= 20 bytes long" do
      assert_raise FunctionClauseError, fn ->
        THR.open_string("hello")
      end
    end

    test "hash is invalid" do
      assert {:ok, device} = THR.open_string("hellobogusbogusbogusbogus")

      assert "hello" = IO.binread(device, 5)
      assert :eof = IO.binread(device, 5)

      refute THR.valid_hash?(device)
    end
  end

  defp open_file_with_trailing_hash(s) do
    Temp.track!()
    path = Temp.path!()

    File.write!(path, string_with_trailing_hash(s))

    THR.open_file(path)
  end

  defp open_string_with_trailing_hash(s) do
    s
    |> string_with_trailing_hash()
    |> THR.open_string()
  end

  defp string_with_trailing_hash(s), do: s <> hash_for_string(s)

  defp hash_for_string(s) do
    :sha
    |> :crypto.hash_init()
    |> :crypto.hash_update(s)
    |> :crypto.hash_final()
  end
end
