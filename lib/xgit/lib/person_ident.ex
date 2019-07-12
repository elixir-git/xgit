defmodule Xgit.Lib.PersonIdent do
  @moduledoc ~S"""
  A combination of a person identity and time in Git.

  Git combines Name + email + time + time zone to specify who wrote or
  committed something.
  """

  @enforce_keys [:name, :email, :when, :tz_offset]
  defstruct [:name, :email, :when, :tz_offset]

  @doc ~S"""
  Sanitize the given string for use in an identity and append to output.

  Trims whitespace from both ends and special characters `\n < >` that
  interfere with parsing; appends all other characters to the output.
  """
  def sanitized(s) when is_binary(s) do
    s
    |> String.trim()
    |> String.replace(~r/[<>\x00-\x0C\x0E-\x1F]/, "")
  end

  @doc ~S"""
  Formats a timezone offset.
  """
  def format_timezone(offset) when is_integer(offset) do
    sign = if offset < 0, do: "-", else: "+"
    offset = if offset < 0, do: -offset, else: offset

    offset_hours = div(offset, 60)
    offset_mins = rem(offset, 60)

    hours_prefix = if offset_hours < 10, do: "0", else: ""
    mins_prefix = if offset_mins < 10, do: "0", else: ""

    "#{sign}#{hours_prefix}#{offset_hours}#{mins_prefix}#{offset_mins}"
  end

  @doc ~S"""
  Formats the person identity for Git storage.
  """
  def to_external_string(%__MODULE__{name: name, email: email, when: whxn, tz_offset: tz_offset})
      when is_binary(name) and is_binary(email) and is_integer(whxn) and is_integer(tz_offset) do
    "#{sanitized(name)} <#{sanitized(email)}> #{div(whxn, 1000)} #{format_timezone(tz_offset)}"
  end
end
