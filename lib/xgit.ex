defmodule Xgit do
  @moduledoc """
  Just a tiny little project.
  """
  use Application

  @doc """
  Start Xgit application.
  """
  @impl true
  def start(_type, _args) do
    Supervisor.start_link([], strategy: :one_for_one)
  end
end
