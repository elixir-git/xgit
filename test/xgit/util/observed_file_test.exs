defmodule Xgit.Util.ObservedFileTest do
  use ExUnit.Case, async: true

  alias Xgit.Util.ObservedFile

  setup do
    Temp.track!()
    tmp_dir = Temp.mkdir!()
    path = Path.join(tmp_dir, "test")
    {:ok, tmp_dir: tmp_dir, path: path}
  end

  describe "initial_state_for_path/3" do
    test "happy path: file exists", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert is_integer(lmt)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "happy path: file doesn't exist", %{path: path} do
      test_pid = self()

      assert %ObservedFile{
               path: ^path,
               exists?: false,
               parsed_state: {:empty_file, ^test_pid}
             } = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      refute_received {:parse_fn, ^path}
      assert_received :empty_fn
      refute_received :empty_fn
    end

    test "error: file is actually a directory", %{path: path} do
      File.mkdir!(path)

      assert_raise ArgumentError,
                   "Xgit.Util.ObservedFile: path #{path} points to an item of type directory; should be a regular file or no file at all",
                   fn ->
                     ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)
                   end
    end

    test "error if parameters incorrect" do
      assert_raise FunctionClauseError, fn ->
        ObservedFile.initial_state_for_path('path', &spy_parse_fn/1, &spy_empty_fn/0)
      end

      assert_raise FunctionClauseError, fn ->
        ObservedFile.initial_state_for_path("path", fn -> :bogus end, &spy_empty_fn/0)
      end

      assert_raise FunctionClauseError, fn ->
        ObservedFile.initial_state_for_path("path", &spy_parse_fn/1, fn _ -> :bogus end)
      end
    end
  end

  describe "maybe_dirty?/1" do
    test "file didn't exist, still doesn't", %{path: path} do
      test_pid = self()

      assert %ObservedFile{
               path: ^path,
               exists?: false,
               parsed_state: {:empty_file, ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received :empty_fn
      refute_received :empty_fn

      assert ObservedFile.maybe_dirty?(of) == false

      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file didn't exist, now does", %{path: path} do
      test_pid = self()

      assert %ObservedFile{
               path: ^path,
               exists?: false,
               parsed_state: {:empty_file, ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received :empty_fn
      refute_received :empty_fn

      File.write!(path, "mumble")

      assert ObservedFile.maybe_dirty?(of) == true

      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file existed, still does (but within racy git window)", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      assert ObservedFile.maybe_dirty?(of) == true

      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file existed, still does (but beyond racy git window)", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      # ugh, but can't think of how to avoid this
      Process.sleep(3000)

      assert ObservedFile.maybe_dirty?(of) == false

      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file existed, updated beyond racy git window", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      # ugh, but can't think of how to avoid this
      Process.sleep(3000)

      File.write!(path, "other mumble")

      assert ObservedFile.maybe_dirty?(of) == true

      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file existed, now deleted", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      File.rm!(path)

      assert ObservedFile.maybe_dirty?(of) == true

      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file existed, became a directory", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      File.rm!(path)
      File.mkdir!(path)

      assert_raise ArgumentError,
                   "Xgit.Util.ObservedFile: path #{path} points to an item of type directory; should be a regular file or no file at all",
                   fn ->
                     ObservedFile.maybe_dirty?(of)
                   end
    end
  end

  describe "update_state_if_maybe_dirty/3" do
    test "file didn't exist, still doesn't", %{path: path} do
      test_pid = self()

      assert %ObservedFile{
               path: ^path,
               exists?: false,
               parsed_state: {:empty_file, ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received :empty_fn
      refute_received :empty_fn

      assert ^of = ObservedFile.update_state_if_maybe_dirty(of, &spy_parse_fn/1, &spy_empty_fn/0)

      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file didn't exist, now does", %{path: path} do
      test_pid = self()

      assert %ObservedFile{
               path: ^path,
               exists?: false,
               parsed_state: {:empty_file, ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received :empty_fn
      refute_received :empty_fn

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = ObservedFile.update_state_if_maybe_dirty(of, &spy_parse_fn/1, &spy_empty_fn/0)

      assert is_integer(lmt)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file existed, still does (but within racy git window)", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      assert ^of = ObservedFile.update_state_if_maybe_dirty(of, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file existed, still does (but beyond racy git window)", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      # ugh, but can't think of how to avoid this
      Process.sleep(3000)

      assert ^of = ObservedFile.update_state_if_maybe_dirty(of, &spy_parse_fn/1, &spy_empty_fn/0)

      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file existed, updated beyond racy git window", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      # ugh, but can't think of how to avoid this
      Process.sleep(3000)

      File.write!(path, "other mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt2,
               parsed_state: {:parsed_file, path, "other mumble", ^test_pid}
             } = ObservedFile.update_state_if_maybe_dirty(of, &spy_parse_fn/1, &spy_empty_fn/0)

      assert lmt2 > lmt

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn
    end

    test "file existed, now deleted", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      File.rm!(path)

      assert %ObservedFile{
               path: ^path,
               exists?: false,
               parsed_state: {:empty_file, ^test_pid}
             } = ObservedFile.update_state_if_maybe_dirty(of, &spy_parse_fn/1, &spy_empty_fn/0)

      refute_received {:parse_fn, ^path}
      assert_received :empty_fn
      refute_received :empty_fn
    end

    test "file existed, became a directory", %{path: path} do
      test_pid = self()

      File.write!(path, "mumble")

      assert %ObservedFile{
               path: ^path,
               exists?: true,
               last_modified_time: lmt,
               parsed_state: {:parsed_file, path, "mumble", ^test_pid}
             } = of = ObservedFile.initial_state_for_path(path, &spy_parse_fn/1, &spy_empty_fn/0)

      assert_received {:parse_fn, ^path}
      refute_received {:parse_fn, ^path}
      refute_received :empty_fn

      File.rm!(path)
      File.mkdir!(path)

      assert_raise ArgumentError,
                   "Xgit.Util.ObservedFile: path #{path} points to an item of type directory; should be a regular file or no file at all",
                   fn ->
                     ObservedFile.update_state_if_maybe_dirty(
                       of,
                       &spy_parse_fn/1,
                       &spy_empty_fn/0
                     )
                   end
    end
  end

  defp spy_parse_fn(path) do
    send(self(), {:parse_fn, path})
    {:parsed_file, path, File.read!(path), self()}
  end

  defp spy_empty_fn do
    send(self(), :empty_fn)
    {:empty_file, self()}
  end
end
