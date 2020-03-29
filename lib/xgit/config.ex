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
        ) :: [String.t()]
  def get_string_list(repository, section, subsection \\ nil, name)

  def get_string_list(repository, section, nil, name) do
    repository
    |> Storage.get_config_entries(section: section, name: name)
    |> entries_to_values()
  end

  def get_string_list(repository, section, subsection, name) do
    repository
    |> Storage.get_config_entries(section: section, subsection: subsection, name: name)
    |> entries_to_values()
  end

  defp entries_to_values(config_entries) do
    Enum.map(config_entries, fn %{value: value} ->
      cover value
    end)
  end
end
