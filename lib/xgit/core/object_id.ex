defmodule Xgit.Core.ObjectId do
  @moduledoc ~S"""
  An object ID is a string that identifies an object within a repository.

  This string must match the format for a SHA-1 hash (i.e. 40 characters
  of lowercase hex).
  """

  @typedoc "A string containing 40 bytes of lowercase hex digits."
  @type t :: String.t()

  @doc ~S"""
  Get the special all-null object ID, often used to stand-in for no object.
  """
  @spec zero :: t
  def zero, do: "0000000000000000000000000000000000000000"

  @doc ~S"""
  Returns `true` if the value is a valid object ID.

  (In other words, is it a string containing 40 characters of lowercase hex?)
  """
  @spec valid?(id :: term) :: boolean
  def valid?(id)

  def valid?(s) when is_binary(s), do: String.length(s) == 40 && String.match?(s, ~r/^[0-9a-f]+$/)
  def valid?(_), do: false
end
