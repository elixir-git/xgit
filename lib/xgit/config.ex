defmodule Xgit.Config do
  @moduledoc ~S"""
  Provides convenience functions to get specific configuration values from a repository.

  IMPORTANT: The on-disk repository implementation (`Xgit.Repository.OnDisk`) does not
  examine configuration directives in global or home directory.
  """

  alias Xgit.Repository
  alias Xgit.Repository.Storage

  import Xgit.Util.ForceCoverage

  @doc ~S"""
  Get the list of strings for this variable.
  """
  @spec get_string_list(
          repository :: Repository.t(),
          section :: String.t(),
          subsection :: String.t() | nil,
          name :: String.t()
        ) :: [String.t() | nil]
  def get_string_list(repository, section, subsection \\ nil, name)

  def get_string_list(repository, section, nil, name)
      when is_binary(section) and is_binary(name) do
    repository
    |> Storage.get_config_entries(section: section, name: name)
    |> entries_to_values()
  end

  def get_string_list(repository, section, subsection, name)
      when is_binary(section) and is_binary(subsection) and is_binary(name) do
    repository
    |> Storage.get_config_entries(section: section, subsection: subsection, name: name)
    |> entries_to_values()
  end

  defp entries_to_values(config_entries) do
    Enum.map(config_entries, fn %{value: value} ->
      cover value
    end)
  end

  @doc ~S"""
  If there is a single string for this variable, return it.

  If there are zero or multiple values for this variable, return `nil`.

  If there is exactly one value, but it was implied (missing `=`), return `:empty`.
  """
  @spec get_string(
          repository :: Repository.t(),
          section :: String.t(),
          subsection :: String.t() | nil,
          name :: String.t()
        ) :: String.t() | nil | :empty
  def get_string(repository, section, subsection \\ nil, name) do
    repository
    |> get_string_list(section, subsection, name)
    |> single_string_value()
  end

  defp single_string_value([value]) when is_binary(value) do
    cover value
  end

  defp single_string_value([nil]) do
    cover :empty
  end

  defp single_string_value(_) do
    cover nil
  end

  @doc ~S"""
  Return the config value interpreted as an integer.

  Use `default` if it can not be interpreted as such.
  """
  @spec get_integer(
          repository :: Repository.t(),
          section :: String.t(),
          subsection :: String.t() | nil,
          name :: String.t(),
          default :: integer()
        ) :: integer()
  def get_integer(repository, section, subsection \\ nil, name, default)
      when is_integer(default) do
    repository
    |> get_string(section, subsection, name)
    |> to_integer_or_default(default)
  end

  defp to_integer_or_default(nil, default) do
    cover default
  end

  defp to_integer_or_default(value, default) do
    case Integer.parse(value) do
      {n, ""} -> cover n
      _ -> cover default
    end
  end

  @doc ~S"""
  Return the config value interpreted as a boolean.

  Use `default` if it can not be interpreted as such.
  """
  @spec get_boolean(
          repository :: Repository.t(),
          section :: String.t(),
          subsection :: String.t() | nil,
          name :: String.t(),
          default :: boolean()
        ) :: boolean()
  def get_boolean(repository, section, subsection \\ nil, name, default)
      when is_boolean(default) do
    repository
    |> get_string(section, subsection, name)
    |> to_lower_if_string()
    |> to_boolean_or_default(default)
  end

  defp to_lower_if_string(nil), do: cover(nil)
  defp to_lower_if_string(s) when is_binary(s), do: String.downcase(s)

  defp to_boolean_or_default("yes", _default), do: cover(true)
  defp to_boolean_or_default("on", _default), do: cover(true)
  defp to_boolean_or_default("true", _default), do: cover(true)
  defp to_boolean_or_default("1", _default), do: cover(true)

  # defp to_boolean_or_default("1", _default), do: cover(true)
  # what does value without = look like?

  defp to_boolean_or_default("no", _default), do: cover(false)
  defp to_boolean_or_default("off", _default), do: cover(false)
  defp to_boolean_or_default("false", _default), do: cover(false)
  defp to_boolean_or_default("0", _default), do: cover(false)

  # defp to_boolean_or_default("1", _default), do: cover(true)
  # what does empty string look like

  defp to_boolean_or_default(_, default), do: cover(default)
end
