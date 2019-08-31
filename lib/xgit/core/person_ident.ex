# Copyright (C) 2007, Dave Watson <dwatson@mimvista.com>
# Copyright (C) 2007, Robin Rosenberg <robin.rosenberg@dewire.com>
# Copyright (C) 2006-2008, Shawn O. Pearce <spearce@spearce.org>
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit/src/org/eclipse/jgit/lib/PersonIdent.java
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

defmodule Xgit.Core.PersonIdent do
  @moduledoc ~S"""
  A combination of a person identity and time in git.
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Util.RawParseUtils

  @typedoc "Time zone offset in minutes +/- from GMT."
  @type tz_offset :: -720..840

  @typedoc ~S"""
  The tuple of name, email, time, and time zone that specifies who wrote or
  committed something.

  ## Struct Members

  * `:name`: (string) human-readable name of the author or committer
  * `:email`: (string) e-mail address for this person
  * `:when`: (integer) time in the Unix epoch in milliseconds
  * `:tz_offset`: (integer) time zone offset from GMT in minutes
  """
  @type t :: %__MODULE__{
          name: String.t(),
          email: String.t(),
          when: integer,
          tz_offset: tz_offset()
        }

  @enforce_keys [:name, :email, :when, :tz_offset]
  defstruct [:name, :email, :when, :tz_offset]

  @doc ~S"""
  Parse a name line (e.g. author, committer, tagger) into a `PersonIdent` struct.

  ## Parameters

  `b` should be a charlist of an "author" or "committer" line pointing to the
  character after the header name and space.

  The functions `Xgit.Util.RawParseUtils.author/1` and `Xgit.Util.RawParseUtils.committer/1`
  will return suitable charlists.

  ## Return Value

  Returns a `PersonIdent` struct or `nil` if the charlist did not point to a
  properly-formatted identity.
  """
  @spec from_byte_list(b :: [byte]) :: t() | nil
  def from_byte_list(b) when is_list(b) do
    with [?< | email_start] <- RawParseUtils.next_lf(b, ?<),
         true <- has_closing_angle_bracket?(email_start),
         email <- RawParseUtils.until_next_lf(email_start, ?>),
         name <- parse_name(b),
         {time, tz} <- parse_tz(email_start) do
      %__MODULE__{
        name: RawParseUtils.decode(name),
        email: RawParseUtils.decode(email),
        when: time,
        tz_offset: tz
      }
    else
      _ -> cover nil
    end
  end

  defp has_closing_angle_bracket?(b), do: Enum.any?(b, &(&1 == ?>))

  defp parse_name(b) do
    b
    |> RawParseUtils.until_next_lf(?<)
    |> Enum.reverse()
    |> drop_first_if_space()
    |> Enum.reverse()
  end

  defp drop_first_if_space([?\s | b]), do: cover(b)
  defp drop_first_if_space(b), do: cover(b)

  defp parse_tz(first_email_start) do
    # Start searching from end of line, as after first name-email pair,
    # another name-email pair may occur. We will ignore all kinds of
    # "junk" following the first email.

    # We've to use (emailE - 1) for the case that raw[email] is LF,
    # otherwise we would run too far. "-2" is necessary to position
    # before the LF in case of LF termination resp. the penultimate
    # character if there is no trailing LF.

    [?> | first_email_end] = RawParseUtils.next_lf(first_email_start, ?>)
    rev = Enum.reverse(first_email_end)

    {tz, rev} = trim_word_and_rev(rev)
    {time, _rev} = trim_word_and_rev(rev)

    case {time, tz} do
      {[_ | _], [_ | _]} ->
        {time |> RawParseUtils.parse_base_10() |> elem(0),
         tz |> RawParseUtils.parse_timezone_offset() |> elem(0)}

      _ ->
        cover {0, 0}
    end
  end

  defp trim_word_and_rev(rev) do
    rev = Enum.drop_while(rev, &(&1 == ?\s))

    word =
      rev
      |> Enum.take_while(&(&1 != ?\s))
      |> Enum.reverse()

    {word, Enum.drop(rev, Enum.count(word))}
  end

  @doc ~S"""
  Sanitize the given string for use in an identity and append to output.

  Trims whitespace from both ends and special characters `\n < >` that
  interfere with parsing; appends all other characters to the output.
  """
  @spec sanitized(s :: String.t()) :: String.t()
  def sanitized(s) when is_binary(s) do
    s
    |> String.trim()
    |> String.replace(~r/[<>\x00-\x0C\x0E-\x1F]/, "")
  end

  @doc ~S"""
  Formats a timezone offset.
  """
  @spec format_timezone(offset :: tz_offset()) :: String.t()
  def format_timezone(offset) when is_integer(offset) do
    sign =
      if offset < 0 do
        cover "-"
      else
        cover "+"
      end

    offset =
      if offset < 0 do
        cover -offset
      else
        offset
      end

    offset_hours = div(offset, 60)
    offset_mins = rem(offset, 60)

    hours_prefix =
      if offset_hours < 10 do
        cover "0"
      else
        cover ""
      end

    mins_prefix =
      if offset_mins < 10 do
        cover "0"
      else
        cover ""
      end

    cover "#{sign}#{hours_prefix}#{offset_hours}#{mins_prefix}#{offset_mins}"
  end

  @doc ~S"""
  Returns `true` if the struct is a valid `PersonIdent`.
  """
  @spec valid?(person_ident :: any) :: boolean
  def valid?(person_ident)

  def valid?(%__MODULE__{name: name, email: email, when: whxn, tz_offset: tz_offset})
      when is_binary(name) and is_binary(email) and is_integer(whxn) and is_integer(tz_offset) and
             tz_offset >= -720 and tz_offset <= 840,
      do: cover(true)

  def valid?(_), do: cover(false)

  @doc ~S"""
  Formats the person identity for git storage.
  """
  @spec to_external_string(person_ident :: t) :: String.t()
  def to_external_string(person_ident)

  def to_external_string(%__MODULE__{name: name, email: email, when: whxn, tz_offset: tz_offset})
      when is_binary(name) and is_binary(email) and is_integer(whxn) and is_integer(tz_offset) do
    cover "#{sanitized(name)} <#{sanitized(email)}> #{div(whxn, 1000)} #{
            format_timezone(tz_offset)
          }"
  end

  defimpl String.Chars do
    defdelegate to_string(person_ident), to: Xgit.Core.PersonIdent, as: :to_external_string
  end
end
