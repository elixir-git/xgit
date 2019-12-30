defmodule Xgit.Util.ParseHeader do
  @moduledoc false
  # Internal utility for parsing headers from commit and tag objects.

  import Xgit.Util.ForceCoverage

  @doc ~S"""
  Returns the next header that can be parsed from the charlist `b`.

  As of this writing, will not parse headers that span multiple lines.
  This may be added later if needed.

  ## Return Values

  `{'header_name', 'header_value', next_data}` if a header is successfully
  identified. `next_data` will be advanced immediately past the LF that
  terminates this header.

  `:no_header_found` if unable to find a header at this location.
  """
  @spec next_header(b :: charlist) ::
          {header :: charlist, value :: charlist, next_data :: charlist} | :no_header_found
  def next_header(b) when is_list(b) do
    with {[_ | _] = header, [?\s | next]} <- Enum.split_while(b, &header_char?/1),
         {value, next} <- Enum.split_while(next, &value_char?/1) do
      cover {header, value, skip_next_lf(next)}
    else
      _ -> cover :no_header_found
    end
  end

  defp header_char?(32), do: cover(false)
  defp header_char?(10), do: cover(false)
  defp header_char?(_), do: cover(true)

  defp value_char?(10), do: cover(false)
  defp value_char?(_), do: cover(true)

  defp skip_next_lf([10 | next]), do: cover(next)
  defp skip_next_lf(next), do: cover(next)
end
