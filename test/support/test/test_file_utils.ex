defmodule Xgit.Test.TestFileUtils do
  @moduledoc false

  # (Testing only) Utils to hack on files

  @doc ~S"""
  Touch a file such that it precedes any "racy git" condition.

  Anyone calling this function has to pinky-swear that they will not modify
  the file within the next three seconds.
  """
  @spec touch_back!(path :: Path.t()) :: :ok
  def touch_back!(path), do: File.touch!(path, System.os_time(:second) - 3)
end
