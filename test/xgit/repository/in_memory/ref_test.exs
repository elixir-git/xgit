defmodule Xgit.Repository.InMemory.RefTest do
  use Xgit.Repository.Test.RefTest, async: true

  alias Xgit.Repository.InMemory

  setup do
    {:ok, repo} = InMemory.start_link()
    %{repo: repo}
  end
end
