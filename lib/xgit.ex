defmodule Xgit do
  @moduledoc """
  Just a tiny little project.
  """
  use Application

  @doc """
  Start Xgit application.
  """
  def start(_type, _args) do
    children = []
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
