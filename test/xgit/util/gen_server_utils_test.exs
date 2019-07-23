defmodule Xgit.Util.GenServerUtilsTest do
  use ExUnit.Case, async: true

  alias Xgit.Util.GenServerUtils

  describe "call!/3" do
    test "returns server PID when response is simply :ok" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])
      assert ^pid = GenServerUtils.call!(pid, :respond_ok)
    end

    test "returns value when response is {:ok, value}" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])
      assert 42 = GenServerUtils.call!(pid, :respond_ok_value)
    end

    test "raises error when response is {:error, reason}" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])

      assert_raise RuntimeError, "foo", fn ->
        GenServerUtils.call!(pid, :respond_error_foo)
      end
    end
  end

  describe "wrap_call_to/4" do
    test "generates appropriate :reply when response is :ok" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])
      assert pid = GenServerUtils.call!(pid, :wrap_ok)
    end

    test "generates appropriate :reply when response is {:ok, value}" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])
      assert "foo" = GenServerUtils.call!(pid, :wrap_ok_foo)
    end

    test "raises when response is {:error, reason}" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])

      assert_raise RuntimeError, "bogus", fn ->
        GenServerUtils.call!(pid, :wrap_error_bogus)
      end
    end

    test "relays error when raised in wrap" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])

      assert_raise CaseClauseError, "no case clause matching: 45", fn ->
        GenServerUtils.call!(pid, :wrap_raise_error)
      end
    end
  end

  describe "delegate_call_to/4" do
    test "generates appropriate :reply when response is :ok" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])
      assert pid = GenServerUtils.call!(pid, :delegate_ok)
    end

    test "generates appropriate :reply when response is {:ok, value}" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])
      assert "foo" = GenServerUtils.call!(pid, :delegate_ok_foo)
    end

    test "raises when response is {:error, reason}" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])

      assert_raise RuntimeError, "bogus", fn ->
        GenServerUtils.call!(pid, :delegate_error_bogus)
      end
    end

    test "relays error when raised in delegate" do
      {:ok, pid} = GenServer.start_link(__MODULE__.TestServer, [])

      assert_raise CaseClauseError, "no case clause matching: 45", fn ->
        GenServerUtils.call!(pid, :delegate_raise_error)
      end
    end
  end

  defmodule TestDelegate do
    @spec delegate_ok(term) :: term
    def delegate_ok(state), do: {:ok, state}

    @spec delegate_ok_foo(term) :: term
    def delegate_ok_foo(state), do: {:ok, "foo", state}

    @spec delegate_error_bogus(term) :: term
    def delegate_error_bogus(state), do: {:error, "bogus", state}

    @spec delegate_raise_error(term) :: term
    def delegate_raise_error(state) do
      case state do
        1 -> :first
        44 -> :ok
      end
    end
  end

  defmodule TestServer do
    use GenServer

    alias Xgit.Util.GenServerUtilsTest.TestDelegate

    import Xgit.Util.GenServerUtils

    @impl true
    def init(_), do: {:ok, nil}

    @spec wrap_ok(term) :: {:ok, term}
    def wrap_ok(state), do: {:ok, state}

    @spec wrap_ok_foo(term) :: {:ok, term}
    def wrap_ok_foo(state), do: {:ok, "foo", state}

    @spec wrap_error_bogus(term) :: {:error, String.t(), term}
    def wrap_error_bogus(state), do: {:error, "bogus", state}

    @spec wrap_raise_error(term) :: :ok | :first
    def wrap_raise_error(state) do
      case state do
        1 -> :first
        44 -> :ok
      end
    end

    @impl true
    def handle_call(:respond_ok, _from, _state), do: {:reply, :ok, nil}
    def handle_call(:respond_ok_value, _from, _state), do: {:reply, {:ok, 42}, nil}
    def handle_call(:respond_error_foo, _from, _state), do: {:reply, {:error, "foo"}, nil}

    def handle_call(:wrap_ok, _from, _state),
      do: wrap_call(__MODULE__, :wrap_ok, [42], 42)

    def handle_call(:wrap_ok_foo, _from, _state),
      do: wrap_call(__MODULE__, :wrap_ok_foo, [44], 44)

    def handle_call(:wrap_error_bogus, _from, _state),
      do: wrap_call(__MODULE__, :wrap_error_bogus, [44], 44)

    def handle_call(:wrap_raise_error, _from, _state),
      do: wrap_call(__MODULE__, :wrap_raise_error, [45], 45)

    def handle_call(:delegate_ok, _from, _state),
      do: delegate_call_to(TestDelegate, :delegate_ok, [42], 42)

    def handle_call(:delegate_ok_foo, _from, _state),
      do: delegate_call_to(TestDelegate, :delegate_ok_foo, [44], 44)

    def handle_call(:delegate_error_bogus, _from, _state),
      do: delegate_call_to(TestDelegate, :delegate_error_bogus, [44], 44)

    def handle_call(:delegate_raise_error, _from, _state),
      do: delegate_call_to(TestDelegate, :delegate_raise_error, [45], 45)
  end
end
