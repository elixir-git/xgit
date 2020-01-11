defmodule Xgit.ConfigEntry do
  @moduledoc ~S"""
  Represents one entry in a git configuration dictionary.

  This is also commonly referred to as a "config _line_" because it typically
  occupies one line in a typical git configuration file.

  The semantically-important portion of a configuration file (i.e. everything
  except comments and whitespace) could be represented by a list of `ConfigEntry`
  structs.
  """

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  Represents an entry in a git config file.

  ## Struct Members

  * `section`: (`String`) section name for the entry
  * `subsection`: (`String` or `nil`) subsection name
  * `name`: (`String`) key name
  * `value`: (`String`, `nil`, or `:remove`) value
    * `nil` if the name is present without an `=`
    * `:remove_all` can be used as an instruction in some APIs to remove any corresponding entries
  """
  @type t :: %__MODULE__{
          section: String.t(),
          subsection: String.t() | nil,
          name: String.t(),
          value: String.t() | nil
        }

  @enforce_keys [:section, :subsection, :name, :value]
  defstruct [:section, :name, subsection: nil, value: nil]

  @doc ~S"""
  Returns `true` if passed a valid config entry.
  """
  @spec valid?(value :: any) :: boolean
  def valid?(%__MODULE__{} = entry) do
    valid_section?(entry.section) &&
      valid_subsection?(entry.subsection) &&
      valid_name?(entry.name) &&
      valid_value?(entry.value)
  end

  def valid?(_), do: cover(false)

  @doc ~S"""
  Returns `true` if passed a valid config section name.

  Only alphanumeric characters, `-`, and `.` are allowed in section names.
  """
  @spec valid_section?(section :: any) :: boolean
  def valid_section?(section) when is_binary(section) do
    String.match?(section, ~r/^[-A-Za-z0-9.]+$/)
  end

  def valid_section?(nil), do: cover(true)
  def valid_section?(_), do: cover(false)

  @doc ~S"""
  Returns `true` if passed a valid config subsection name.
  """
  @spec valid_subsection?(subsection :: any) :: boolean
  def valid_subsection?(subsection) when is_binary(subsection) do
    if String.match?(subsection, ~r/[\0\n]/) do
      cover false
    else
      cover true
    end
  end

  def valid_subsection?(nil), do: cover(true)
  def valid_subsection?(_), do: cover(false)

  @doc ~S"""
  Returns `true` if passed a valid config entry name.
  """
  @spec valid_name?(name :: any) :: boolean
  def valid_name?(name) when is_binary(name) do
    String.match?(name, ~r/^[A-Za-z][-A-Za-z0-9]*$/)
  end

  def valid_name?(_), do: cover(false)

  @doc ~S"""
  Returns `true` if passed a valid config value string.

  Important: At this level, we do not accept other data types.
  """
  @spec valid_value?(value :: any) :: boolean
  def valid_value?(value) when is_binary(value) do
    if String.match?(value, ~r/\0/) do
      cover false
    else
      cover true
    end
  end

  def valid_value?(nil), do: cover(true)
  def valid_value?(:remove_all), do: cover(true)
  def valid_value?(_), do: cover(false)
end
