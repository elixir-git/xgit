defmodule Xgit.Util.Comparison do
  @moduledoc false

  # Internal common vocabulary for data types that can be compared and/or sorted.

  @typedoc """
  Result of a comparison.
  """
  @type result :: :lt | :eq | :gt
end
