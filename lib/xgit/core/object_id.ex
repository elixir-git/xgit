defmodule Xgit.Core.ObjectId do
  @moduledoc ~S"""
  An object ID is a string that identifies an object within a repository.

  This string must match the format for a SHA-1 hash (i.e. 40 characters
  of lowercase hex).
  """

  @type t :: String.t()

  @doc ~S"""
  Get the special all-null object ID, often used to stand-in for no object.
  """
  @spec zero :: t
  def zero, do: "0000000000000000000000000000000000000000"

  @doc ~S"""
  Returns `true` if the string is a valid object ID.
  (In other words, is it 40 characters of lowercase hex?)
  """
  @spec valid?(id :: String.t() | nil) :: boolean
  def valid?(id)

  def valid?(s) when is_binary(s), do: String.length(s) == 40 && String.match?(s, ~r/^[0-9a-f]+$/)
  def valid?(nil), do: false
end
