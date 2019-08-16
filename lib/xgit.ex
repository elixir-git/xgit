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
    children = [
      {ConCache,
       name: :xgit_file_snapshot,
       ttl_check_interval: :timer.seconds(1),
       global_ttl: :timer.seconds(5)}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
