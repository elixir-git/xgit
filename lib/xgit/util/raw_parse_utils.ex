# Copyright (C) 2008-2009, Google Inc.
# Copyright (C) 2006-2008, Shawn O. Pearce <spearce@spearce.org>
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit/src/org/eclipse/jgit/util/RawParseUtils.java
#
# Copyright (C) 2019, Eric Scouten <eric+xgit@scouten.com>
#
# This program and the accompanying materials are made available
# under the terms of the Eclipse Distribution License v1.0 which
# accompanies this distribution, is reproduced below, and is
# available at http://www.eclipse.org/org/documents/edl-v10.php
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# - Redistributions in binary form must reproduce the above
#   copyright notice, this list of conditions and the following
#   disclaimer in the documentation and/or other materials provided
#   with the distribution.
#
# - Neither the name of the Eclipse Foundation, Inc. nor the
#   names of its contributors may be used to endorse or promote
#   products derived from this software without specific prior
#   written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

defmodule Xgit.Util.RawParseUtils do
  @moduledoc ~S"""
  Handy utility functions to parse raw object contents.
  """

  import Xgit.Util.ForceCoverage

  @doc ~S"""
  Return the portion of the charlist `b` that starts with the prefix `prefix`.

  ## Return Values

  If `b` does in fact start with `prefix`, return the portion of the charlist
  that follows `prefix`.

  If not, return `nil`.
  """
  @spec after_prefix(b :: charlist, prefix :: charlist) :: charlist | nil
  def after_prefix(b, prefix)

  def after_prefix(b, []), do: cover(b)
  def after_prefix([c | b], [c | prefix]), do: after_prefix(b, prefix)
  def after_prefix(_, _), do: cover(nil)

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
  @spec parse_base_10(b :: charlist) :: {integer, charlist}
  def parse_base_10(b) when is_list(b) do
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

  @doc ~S"""
  Parse 4 hex digits from a byte list to an integer.

  The number is read in network byte order, that is, most significant
  nybble first.

  ## Return Value

  Returns `{number, new_buffer}` where `number` is the integer that was
  found (or 0 if no number found there) and `new_buffer` is the charlist
  following the number that was parsed.
  """
  @spec parse_hex_int16(b :: charlist) :: {integer, charlist}
  def parse_hex_int16(b) when is_list(b), do: parse_hex_digits(b, 0, 4)

  @doc ~S"""
  Parse 8 hex digits from a byte list to an integer.

  The number is read in network byte order, that is, most significant
  nybble first.

  ## Return Value

  Returns `{number, new_buffer}` where `number` is the integer that was
  found (or 0 if no number found there) and `new_buffer` is the charlist
  following the number that was parsed.
  """
  @spec parse_hex_int32(b :: charlist) :: {integer, charlist}
  def parse_hex_int32(b) when is_list(b), do: parse_hex_digits(b, 0, 8)

  @doc ~S"""
  Parse 16 hex digits from a byte list to an integer.

  The number is read in network byte order, that is, most significant
  nybble first.

  ## Return Value

  Returns `{number, new_buffer}` where `number` is the integer that was
  found (or 0 if no number found there) and `new_buffer` is the charlist
  following the number that was parsed.
  """
  @spec parse_hex_int64(b :: charlist) :: {integer, charlist}
  def parse_hex_int64(b) when is_list(b), do: parse_hex_digits(b, 0, 16)

  @doc ~S"""
  Parse a single hex digit from a byte list to an integer.

  The number is read in network byte order, that is, most significant
  nybble first.

  ## Return Value

  Returns `{number, new_buffer}` where `number` is the integer that was
  found (or 0 if no number found there) and `new_buffer` is the charlist
  following the number that was parsed.
  """
  @spec parse_hex_int4(b :: charlist) :: {integer, charlist}
  def parse_hex_int4(b) when is_list(b), do: parse_hex_digits(b, 0, 1)

  defp parse_hex_digits(b, n, 0), do: cover({n, b})

  defp parse_hex_digits([d | b], n, rem) when d >= ?0 and d <= ?9,
    do: parse_hex_digits(b, n * 16 + (d - ?0), rem - 1)

  defp parse_hex_digits([d | b], n, rem) when d >= ?A and d <= ?F,
    do: parse_hex_digits(b, n * 16 + (d - ?A + 10), rem - 1)

  defp parse_hex_digits([d | b], n, rem) when d >= ?a and d <= ?f,
    do: parse_hex_digits(b, n * 16 + (d - ?a + 10), rem - 1)

  @doc ~S"""
  Parse a git-style timezone string.

  The sequence `-0315` will be parsed as the numeric value -195, as the
  lower two positions count minutes, not 100ths of an hour.

  ## Return Value

  Returns `{number, new_buffer}` where `number` is the time zone offset in minutes
  that was found (or 0 if no number found there) and `new_buffer` is the charlist
  following the number that was parsed.
  """
  @spec parse_timezone_offset(b :: charlist) :: {Xgit.Core.PersonIdent.tz_offset(), charlist}
  def parse_timezone_offset(b) when is_list(b) do
    {v, b} = parse_base_10(b)

    tz_min = rem(v, 100)
    tz_hour = div(v, 100)

    cover {tz_hour * 60 + tz_min, b}
  end

  @doc ~S"""
  Locate the first position after a given character.
  """
  @spec next(b :: charlist, char :: char) :: charlist
  def next(b, char)

  def next([char | b], char) when is_integer(char), do: b
  def next([_ | b], char) when is_integer(char), do: next(b, char)
  def next([], char) when is_integer(char), do: cover([])

  @doc ~S"""
  Locate the first position after the next LF.

  This method stops on the first `\n` it finds.
  """
  @spec next_lf(b :: charlist) :: charlist
  def next_lf(b), do: next(b, ?\n)

  @doc ~S"""
  Locate the first position of either the given character or LF.

  This method stops on the first match it finds from either `char` or `\n`.
  """
  @spec next_lf(b :: charlist, char :: char) :: charlist
  def next_lf(b, char)

  def next_lf([char | _] = b, char) when is_integer(char), do: b
  def next_lf([?\n | _] = b, char) when is_integer(char), do: b
  def next_lf([_ | b], char) when is_integer(char), do: next_lf(b, char)
  def next_lf([], char) when is_integer(char), do: cover([])

  @doc ~S"""
  Return the contents of the charlist up to, but not including, the next LF.
  """
  @spec until_next_lf(b :: charlist) :: charlist
  def until_next_lf(b), do: Enum.take_while(b, fn c -> c != ?\n end)

  @doc ~S"""
  Return the contents of the charlist up to, but not including, the next instance
  of the given character or LF.
  """
  @spec until_next_lf(b :: charlist, char :: char) :: charlist
  def until_next_lf(b, char), do: Enum.take_while(b, fn c -> c != ?\n and c != char end)

  @doc ~S"""
  Locate the end of the header. Note that headers may be more than one line long.

  Returns charlist beginning just after the header. This is either `[]` or the
  charlist beginning with the `\n` character that terminates the header.
  """
  @spec header_end(b :: charlist) :: charlist
  def header_end(b)

  def header_end([?\n | [?\s | b]]), do: header_end(b)
  def header_end([?\n | _] = b), do: b
  def header_end([]), do: cover([])
  def header_end([_ | b]), do: header_end(b)

  @doc ~S"""
  Find the start of the contents of a given header in the given charlist.

  Returns charlist beginning at the start of the header's contents or `nil`
  if not found.

  _PORTING NOTE:_ Unlike the jgit version of this function, it does not advance
  to the beginning of the next line. Because the API speaks in charlists, we cannot
  differentiate between the beginning of the initial string buffer and a subsequent
  internal portion of the buffer. Clients may need to add their own call to `next_lf/1`
  where it would not have been necessary in jgit.
  """
  @spec header_start(header_name :: charlist, b :: charlist) :: charlist | nil
  def header_start([_ | _] = header_name, b) when is_list(b),
    do: possible_header_match(header_name, header_name, b, b)

  defp possible_header_match(header_name, [c | rest_of_header], match_start, [c | rest_of_match]),
    do: possible_header_match(header_name, rest_of_header, match_start, rest_of_match)

  defp possible_header_match(_header_name, [], _match_start, [?\s | header_content]),
    do: header_content

  defp possible_header_match(_header_name, _, [], _), do: cover(nil)

  defp possible_header_match(header_name, _, [_ | b], _),
    do: possible_header_match(header_name, header_name, b, b)

  @doc ~S"""
  Locate the `author ` header line data.

  Returns a charlist beginning just after the space in `author ` which should be
  the first character of the author's name. If no author header can be located,
  `nil` is returned.
  """
  @spec author(b :: charlist) :: charlist | nil
  def author(b) when is_list(b), do: header_start('author', b)

  @doc ~S"""
  Locate the `committer ` header line data.

  Returns a charlist beginning just after the space in `committer ` which should be
  the first character of the committer's name. If no committer header can be located,
  `nil` is returned.
  """
  @spec committer(b :: charlist) :: charlist | nil
  def committer(b) when is_list(b), do: header_start('committer', b)

  @doc ~S"""
  Locate the `tagger ` header line data.

  Returns a charlist beginning just after the space in `tagger ` which should be
  the first character of the tagger's name. If no tagger header can be located,
  `nil` is returned.
  """
  @spec tagger(b :: charlist) :: charlist | nil
  def tagger(b) when is_list(b), do: header_start('tagger', b)

  @doc ~S"""
  Locate the `encoding ` header line data.

  Returns a charlist beginning just after the space in `encoding ` which should be
  the first character of the encoding's name. If no encoding header can be located,
  `nil` is returned (and UTF-8 should be assumed).
  """
  @spec encoding(b :: charlist) :: charlist | nil
  def encoding(b) when is_list(b), do: header_start('encoding', b)

  @doc ~S"""
  Parse the `encoding ` header as a string.

  Returns the encoding header as specified in the commit or `nil` if the header
  was not present and UTF-8 should be assumed.
  """
  @spec parse_encoding_name(b :: charlist) :: String.t() | nil
  def parse_encoding_name(b) when is_list(b) do
    enc = encoding(b)

    if enc == nil do
      cover nil
    else
      enc
      |> until_next_lf()
      |> decode()
    end
  end

  @doc ~S"""
  Parse the `encoding ` header into a character set reference.

  Returns `:utf8` or `:latin1`.

  Raises `ArgumentError` if the character set is unknown.

  _WARNING:_ Compared to jgit, the character set support in xgit is limited.
  """
  @spec parse_encoding(b :: charlist) :: :utf8 | :latin1
  def parse_encoding(b) when is_list(b) do
    case b |> parse_encoding_name() |> trim_if_string() do
      nil -> cover :utf8
      "UTF-8" -> cover :utf8
      "ISO-8859-1" -> cover :latin1
      x -> raise ArgumentError, "charset #{inspect(x)} unsupported"
    end
  end

  defp trim_if_string(s) when is_binary(s), do: String.trim(s)
  defp trim_if_string(s), do: s

  @doc ~S"""
  Convert a list of bytes to an Elixir (UTF-8) string when the encoding is not
  definitively known. Try parsing as a UTF-8 byte array first, then try ISO-8859-1.

  _PORTING NOTE:_ A lot of the simplification of this compared to jgit's implementation
  of RawParseUtils.decode comes from the observation that the only character set
  ever passed to jgit's decode was UTF-8. We've baked that assumption into this
  implementation. Should other character sets come into play, this will necessarily
  become more complicated.
  """
  @spec decode(b :: [byte]) :: String.t()
  def decode(b) when is_list(b) do
    raw = :erlang.list_to_binary(b)

    case :unicode.characters_to_binary(raw) do
      utf8 when is_binary(utf8) -> utf8
      _ -> :unicode.characters_to_binary(raw, :latin1)
    end
  end

  @doc ~S"""
  Return the contents of the charlist up to, but not including, the next end-of-paragraph
  sequence.
  """
  @spec until_end_of_paragraph(b :: [byte]) :: [byte]
  def until_end_of_paragraph(b) when is_list(b),
    do: until_end_of_paragraph([], b)

  defp until_end_of_paragraph(acc, [?\r | [?\n | [?\r | _]]]), do: acc
  defp until_end_of_paragraph(acc, [?\n | [?\n | _]]), do: acc
  defp until_end_of_paragraph(acc, [c | rem]), do: until_end_of_paragraph(acc ++ [c], rem)
  defp until_end_of_paragraph(acc, []), do: acc

  @doc ~S"""
  Return the portion of the byte array up to, but not including the last instance of
  `ch`, disregarding any trailing spaces.
  """
  @spec until_last_instance_of_trim(b :: [byte], ch :: char) :: [byte]
  def until_last_instance_of_trim(b, ch) when is_list(b) do
    b
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == ?\s))
    |> Enum.drop_while(&(&1 != ch))
    |> Enum.drop(1)
    |> Enum.reverse()
  end
end
