defmodule Xgit.Util.Comparison do
  @moduledoc ~S"""
  Common vocabulary for data types that can be compared and/or sorted.
  """

  @typedoc """
  Result of a comparison.
  """
  @type result :: :lt | :eq | :gt
end
