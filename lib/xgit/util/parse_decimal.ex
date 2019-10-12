defmodule Xgit.Util.ParseDecimal do
  @moduledoc false
  # Internal utility for parsing decimal values from charlist.

  import Xgit.Util.ForceCoverage

  @doc ~S"""
  Parse a base-10 numeric value from a charlist of ASCII digits into a number.

  Similar to `Integer.parse/2` but uses charlist instead.

  Digit sequences can begin with an optional run of spaces before the
  sequence, and may start with a `+` or a `-` to indicate sign position.
  Any other characters will cause the method to stop and return the current
  result to the caller.

  Returns `{number, new_buffer}` where `number` is the integer that was
  found (or 0 if no number found there) and `new_buffer` is the charlist
  following the number that was parsed.
  """
  @spec from_decimal_charlist(b :: charlist) :: {integer, charlist}
  def from_decimal_charlist(b) when is_list(b) do
    b = skip_white_space(b)
    {sign, b} = parse_sign(b)
    {n, b} = parse_digits(0, b)

    cover {sign * n, b}
  end

  defp skip_white_space([?\s | b]), do: skip_white_space(b)
  defp skip_white_space(b), do: b

  defp parse_sign([?- | b]), do: cover({-1, b})
  defp parse_sign([?+ | b]), do: cover({1, b})
  defp parse_sign(b), do: cover({1, b})

  defp parse_digits(n, [d | b]) when d >= ?0 and d <= ?9, do: parse_digits(n * 10 + (d - ?0), b)
  defp parse_digits(n, b), do: cover({n, b})
end
