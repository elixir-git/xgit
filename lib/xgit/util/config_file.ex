defmodule Xgit.Util.ConfigFile do
  @moduledoc false

  # This GenServer monitors and potentially updates the contents
  # of an on-disk git config file. It is primarily intended to be
  # used by Xgit.Repository.OnDisk, but may be of use elsewhere.

  use GenServer

  require Logger

  alias Xgit.ConfigEntry
  alias Xgit.Util.ObservedFile
  alias Xgit.Util.ParseCharlist

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  Process ID for an `Xgit.ConfigFile` process.
  """
  @type t :: pid

  defmodule Line do
    @moduledoc false

    # Wraps the public Xgit.ConfigEntry with some additional infrastructure
    # that lets us reconstruct the exact contents of the file.

    defstruct [:entry, :original, :section, :subsection]
  end

  @doc ~S"""
  Start a `ConfigFile` for a config file at the given path.

  The path (including parent directory) needs to exist, but there
  need not be a file at this path.
  """
  @spec start_link(path :: Path.t()) :: GenServer.on_start()
  def start_link(path) when is_binary(path) do
    unless File.dir?(Path.dirname(path)) do
      raise ArgumentError,
            "Xgit.Util.ConfigFile.start_link/1: Parent of path #{path} must be an existing directory"
    end

    GenServer.start_link(__MODULE__, path)
  end

  @impl true
  def init(path) when is_binary(path) do
    cover {:ok,
           ObservedFile.initial_state_for_path(path, &parse_config_at_path/1, &empty_config/0)}
  end

  @typedoc ~S"""
  Error codes that can be returned by `get_entries/2`.
  """
  @type get_entries_reason :: File.posix()

  @doc ~S"""
  Return any configuration entries that match the requested search.

  Entries will be returned in the order in which they appeared in the underlying file.

  ## Options

  * `section:` (`String`) if provided, only returns entries in the named section
  * `subsection:` (`String`) if provided, only returns entries in the named subsection
    (only meaningful if `section` is also provided)
  * `name:` (`String`) if provided, only returns entries with the given variable name
    (only meaningful if `section` is also provided)

  If `section` is provided but `subsection` is not, then only items within the top-level
  section (i.e. with no subsection) will be matched.

  If no options are provided, returns all entries.

  ## Return Values

  `{:ok, [entries]}` where `entries` is a list of `Xgit.ConfigEntry` structs that match the
  search parameters.
  """
  @spec get_entries(config_file :: t,
          section: String.t(),
          subsection: String.t(),
          name: String.t()
        ) ::
          {:ok, entries :: [Xgit.ConfigEntry.t()]} | {:error, reason :: get_entries_reason}
  def get_entries(config_file, opts \\ []) when is_pid(config_file) and is_list(opts),
    do: GenServer.call(config_file, {:get_entries, opts})

  defp handle_get_entries(%ObservedFile{} = of, opts) when is_list(opts) do
    %{parsed_state: lines} =
      of = ObservedFile.update_state_if_maybe_dirty(of, &parse_config_at_path/1, &empty_config/0)

    opts = Enum.into(opts, %{})

    entries =
      lines
      |> Enum.filter(&(&1.entry != nil))
      |> Enum.map(& &1.entry)
      |> Enum.filter(&matches_opts?(&1, opts))

    {:reply, {:ok, entries}, of}
  end

  defp matches_opts?(item, %{section: section, name: name} = opts) do
    subsection = Map.get(opts, :subsection)
    item.section == section && item.subsection == subsection && item.name == name
  end

  defp matches_opts?(item, %{section: section} = opts) do
    subsection = Map.get(opts, :subsection)
    item.section == section && item.subsection == subsection
  end

  defp matches_opts?(_item, _opts), do: cover(true)

  ## --- Parsing ---

  defp parse_config_at_path(path) do
    path
    |> File.stream!()
    |> Enum.to_list()
    |> Enum.map(&String.replace_suffix(&1, "\n", ""))
    |> Enum.reduce([], &join_backslashed_lines/2)
    |> Enum.reverse()
    |> Enum.reduce({[], nil, nil}, &text_to_line/2)
    |> elem(0)
    |> Enum.reverse()
  end

  defp join_backslashed_lines(line, [most_recent_line | tail] = reversed_lines) do
    if String.ends_with?(most_recent_line, "\\") and
         not String.ends_with?(most_recent_line, "\\\\") do
      most_recent_line = String.replace_suffix(most_recent_line, "\\", "")
      cover ["#{most_recent_line}\n#{line}" | tail]
    else
      cover [line | reversed_lines]
    end
  end

  defp join_backslashed_lines(line, reversed_lines), do: cover([line | reversed_lines])

  defp text_to_line(line, {reversed_lines, section, subsection}) do
    {section, subsection, entry} =
      charlist_to_entry(String.to_charlist(line), section, subsection)

    {[
       %__MODULE__.Line{entry: entry, original: line, section: section, subsection: subsection}
       | reversed_lines
     ], section, subsection}
  end

  defp charlist_to_entry(line, section, subsection) do
    remainder = Enum.drop_while(line, &whitespace?/1)

    {section, subsection, remainder} =
      read_optional_section_header(remainder, section, subsection)

    {var_name, value, remainder} = read_optional_variable(remainder)

    case Enum.drop_while(remainder, &whitespace?/1) do
      [] -> cover :ok
      [?# | _] -> cover :ok
      [?; | _] -> cover :ok
      _ -> raise ArgumentError, "Illegal variable declaration: #{line}"
    end

    {section, subsection, maybe_config_entry(section, subsection, var_name, value)}
  end

  defp whitespace?(?\s), do: cover(true)
  defp whitespace?(?\t), do: cover(true)
  defp whitespace?(_), do: cover(false)

  defp read_optional_section_header([?[ | remainder] = line, _section, _subsection) do
    remainder = Enum.drop_while(remainder, &whitespace?/1)
    {section, remainder} = Enum.split_while(remainder, &section_name_char?/1)
    remainder = Enum.drop_while(remainder, &whitespace?/1)
    {subsection, remainder} = read_optional_subsection_header(remainder)
    remainder = Enum.drop_while(remainder, &whitespace?/1)

    remainder =
      case remainder do
        [?] | x] -> Enum.drop_while(x, &whitespace?/1)
        _ -> raise ArgumentError, "Illegal section header #{line}"
      end

    {section |> to_string() |> String.downcase(), subsection, remainder}
  end

  defp read_optional_section_header(remainder, section, subsection),
    do: cover({section, subsection, remainder})

  defp section_name_char?(c) when c >= ?A and c <= ?Z, do: cover(true)
  defp section_name_char?(c) when c >= ?a and c <= ?z, do: cover(true)
  defp section_name_char?(c) when c >= ?0 and c <= ?9, do: cover(true)
  defp section_name_char?(?-), do: cover(true)
  defp section_name_char?(?.), do: cover(true)
  defp section_name_char?(_), do: cover(false)

  defp read_optional_subsection_header([?" | _] = remainder) do
    {subsection, remainder} = read_quoted_string(remainder)
    {to_string(subsection), remainder}
  end

  defp read_optional_subsection_header(remainder), do: cover({nil, remainder})

  defp read_optional_variable(remainder) do
    {var_name, remainder} = Enum.split_while(remainder, &var_name_char?/1)

    if Enum.empty?(var_name) do
      cover {nil, nil, remainder}
    else
      {value, remainder} = read_optional_value(remainder)
      cover {var_name |> to_string() |> String.downcase(), value, remainder}
    end
  end

  defp var_name_char?(c) when c >= ?A and c <= ?Z, do: cover(true)
  defp var_name_char?(c) when c >= ?a and c <= ?z, do: cover(true)
  defp var_name_char?(c) when c >= ?0 and c <= ?9, do: cover(true)
  defp var_name_char?(?-), do: cover(true)
  defp var_name_char?(_), do: cover(false)

  defp read_optional_value(remainder) do
    remainder = Enum.drop_while(remainder, &whitespace?/1)

    if List.first(remainder) == ?= do
      {value, remainder} =
        remainder
        |> Enum.drop(1)
        |> Enum.drop_while(&whitespace?/1)
        |> read_possibly_quoted_string()

      cover {ParseCharlist.decode_ambiguous_charlist(value), remainder}
    else
      cover {nil, remainder}
    end
  end

  defp read_quoted_string([?" | remainder]) do
    {quoted_string, remainder} = read_quoted_string([], remainder)
    {Enum.reverse(quoted_string), remainder}
  end

  defp read_quoted_string(_acc, [?\n | _remainder]) do
    raise ArgumentError, "Illegal quoted string: Can not span a new line"
  end

  defp read_quoted_string(_acc, []) do
    raise ArgumentError, "Illegal quoted string: Missing close quote"
  end

  defp read_quoted_string(acc, [?\\ | [c | remainder]]),
    do: read_quoted_string([c | acc], remainder)

  defp read_quoted_string(acc, [?" | remainder]), do: cover({acc, remainder})
  defp read_quoted_string(acc, [c | remainder]), do: read_quoted_string([c | acc], remainder)

  defp read_possibly_quoted_string(remainder), do: read_possibly_quoted_string([], remainder)

  defp read_possibly_quoted_string(acc, [c | _] = remainder) when c == ?\s or c == ?\t do
    {whitespace, remainder} = Enum.split_while(remainder, &whitespace?/1)

    case remainder do
      [] -> cover {acc, remainder}
      [?; | _] -> cover {acc, []}
      [?# | _] -> cover {acc, []}
      x -> read_possibly_quoted_string(acc ++ whitespace, x)
    end
  end

  defp read_possibly_quoted_string(acc, [?" | remainder]),
    do: read_quoted_value_section(acc, remainder)

  defp read_possibly_quoted_string(acc, []), do: cover({acc, []})

  defp read_possibly_quoted_string(acc, remainder) do
    {non_whitespace, remainder} = Enum.split_while(remainder, &(!whitespace?(&1)))
    read_possibly_quoted_string(acc ++ non_whitespace, remainder)
  end

  defp read_quoted_value_section(acc, [?\\ | [?" | remainder]]),
    do: read_quoted_value_section(acc ++ [?"], remainder)

  defp read_quoted_value_section(acc, [?\\ | [?\\ | remainder]]),
    do: read_quoted_value_section(acc ++ [?\\], remainder)

  defp read_quoted_value_section(acc, [?\\ | [?n | remainder]]),
    do: read_quoted_value_section(acc ++ [?\n], remainder)

  defp read_quoted_value_section(acc, [?\\ | [?t | remainder]]),
    do: read_quoted_value_section(acc ++ [?\t], remainder)

  defp read_quoted_value_section(acc, [?\\ | [?b | remainder]]),
    do: read_quoted_value_section(acc ++ [8], remainder)

  defp read_quoted_value_section(_acc, [?\\ | [c | _remainder]]),
    do: raise(ArgumentError, "Invalid config file: Unknown escape sequence \\#{[c]}")

  defp read_quoted_value_section(acc, [?" | remainder]),
    do: read_possibly_quoted_string(acc, remainder)

  defp read_quoted_value_section(_acc, []), do: raise(ArgumentError, "Incomplete quoted string")

  defp read_quoted_value_section(acc, [c | remainder]),
    do: read_quoted_value_section(acc ++ [c], remainder)

  defp maybe_config_entry(_section, _subsection, nil = _var_name, _value), do: cover(nil)

  defp maybe_config_entry(nil = _section, _subsection, var_name, _value) do
    raise ArgumentError,
          "Invalid config file: Assigning variable #{var_name} without a section header"
  end

  defp maybe_config_entry(section, subsection, var_name, value) when is_binary(section) do
    cover(%ConfigEntry{section: section, subsection: subsection, name: var_name, value: value})
  end

  defp empty_config, do: cover([])

  @typedoc ~S"""
  Error codes that can be returned by `add_config_entries/3`.
  """
  @type add_config_entries_reason :: File.posix()

  @doc ~S"""
  Add one or more new entries to an existing config.

  The entries need not be sorted. However, if multiple values are provided
  for the same variable (section, subsection, name tuple), they will be added
  in the order provided here.

  ## Parameters

  `entries` (list of `Xgit.ConfigEntry`) entries to be added

  ## Options

  `add?`: if `true`, adds these entries to any that may already exist
  `replace_all?`: if `true`, removes all existing entries that match any keys provided

  See also the `:remove_all` option for the `value` member of `Xgit.ConfigEntry`.

  ## Return Values

  `:ok` if successful.

  `{:error, reason}` if unable. `reason` is likely a POSIX error code.
  """
  @spec add_config_entries(config_file :: t, entries :: [Xgit.ConfigEntry.t()],
          add?: boolean,
          replace_all?: boolean
        ) ::
          :ok | {:error, config_file :: add_config_entries_reason}
  def add_config_entries(config_file, entries, opts \\ [])
      when is_pid(config_file) and is_list(entries) and is_list(opts) do
    if Enum.all?(entries, &ConfigEntry.valid?/1) do
      GenServer.call(config_file, {:add_config_entries, entries, opts})
    else
      raise ArgumentError,
            "Xgit.Util.ConfigFile.add_config_entries/3: one or more entries are invalid"
    end
  end

  defp handle_add_config_entries(%ObservedFile{} = of, _entries, opts) do
    %{parsed_state: lines} =
      of = ObservedFile.update_state_if_maybe_dirty(of, &parse_config_at_path/1, &empty_config/0)

    add? = Keyword.get(opts, :add?, false)
    replace_all? = Keyword.get(opts, :replace_all?, false)

      raise "unimplemented"
  end

  ## --- Callbacks ---

  @impl true
  def handle_call({:get_entries, opts}, _from, state), do: handle_get_entries(state, opts)

  def handle_call({:add_config_entries, entries, opts}, _from, state),
    do: handle_add_config_entries(state, entries, opts)

  def handle_call(message, _from, state) do
    Logger.warn("ConfigFile received unrecognized call #{inspect(message)}")
    {:reply, {:error, :unknown_message}, state}
  end
end
