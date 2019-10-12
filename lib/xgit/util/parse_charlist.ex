defmodule Xgit.Util.ParseCharlist do
  @moduledoc false
  # Internal utility for parsing charlists with ambiguous encodings.

  @doc ~S"""
  Convert a list of bytes to an Elixir (UTF-8) string when the encoding is not
  definitively known. Try parsing as a UTF-8 byte array first, then try ISO-8859-1.
  """
  @spec decode_ambiguous_charlist(b :: [byte]) :: String.t()
  def decode_ambiguous_charlist(b) when is_list(b) do
    raw = :erlang.list_to_binary(b)

    case :unicode.characters_to_binary(raw) do
      utf8 when is_binary(utf8) -> utf8
      _ -> :unicode.characters_to_binary(raw, :latin1)
    end
  end
end
