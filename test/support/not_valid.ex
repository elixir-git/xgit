defmodule NotValid do
  @moduledoc false
  # This module can be used to test the invalid case for Repository.valid?
  # and similar. It will not respond properly to such messages.

  use GenServer

  @impl true
  def init(nil), do: {:ok, nil}

  @impl true
  def handle_call(_request, _from, _state), do: {:reply, :whatever, nil}
end
