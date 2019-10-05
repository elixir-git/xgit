defmodule Xgit.Test.TempDirTestCase do
  @moduledoc ~S"""
  (Testing only) Test case that sets up a temporary directory.
  """

  @doc ~S"""
  Returns a context with a temporary directory set up.
  """
  @spec tmp_dir!() :: %{tmp_dir: Path.t()}
  def tmp_dir! do
    Temp.track!()
    %{tmp_dir: Temp.mkdir!()}
  end
end
