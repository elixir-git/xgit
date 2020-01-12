defmodule Xgit.Repository.InMemory.ConfigTest do
  use Xgit.Repository.Test.ConfigTest, async: true

  alias Xgit.Repository.InMemory

  setup do
    {:ok, repo} = InMemory.start_link()
    %{repo: repo}
  end
end
