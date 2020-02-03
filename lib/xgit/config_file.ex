defmodule Xgit.ConfigFile do
  @moduledoc ~S"""
  This GenServer monitors and potentially updates the contents
  of an on-disk git config file.

  See https://git-scm.com/docs/git-config for details on the config file format.
  """

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
            "Xgit.ConfigFile.start_link/1: Parent of path #{path} must be an existing directory"
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

  `{:error, reason}` if unable. `reason` is likely a POSIX error code.
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
    cover {Enum.reverse(quoted_string), remainder}
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
  Error codes that can be returned by `add_entries/3`.
  """
  @type add_entries_reason :: File.posix() | :replacing_multivar

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

  `{:error, :replacing_multivar}` if the existing variable has multiple variables.
  Replacing such a variable requires either `add?: true` or `replace_all?: true`.

  `{:error, reason}` if unable. `reason` is likely a POSIX error code.
  """
  @spec add_entries(config_file :: t, entries :: [Xgit.ConfigEntry.t()],
          add?: boolean,
          replace_all?: boolean
        ) ::
          :ok | {:error, config_file :: add_entries_reason}
  def add_entries(config_file, entries, opts \\ [])
      when is_pid(config_file) and is_list(entries) and is_list(opts) do
    if Keyword.get(opts, :add?) && Keyword.get(opts, :replace_all?) do
      raise ArgumentError,
            "Xgit.ConfigFile.add_entries/3: add? and replace_all? can not both be true"
    end

    if Enum.all?(entries, &ConfigEntry.valid?/1) do
      GenServer.call(config_file, {:add_entries, entries, opts})
    else
      raise ArgumentError,
            "Xgit.ConfigFile.add_entries/3: one or more entries are invalid"
    end
  end

  defp handle_add_entries(%ObservedFile{path: path} = of, entries, opts) do
    %{parsed_state: lines} =
      of = ObservedFile.update_state_if_maybe_dirty(of, &parse_config_at_path/1, &empty_config/0)

    add? = Keyword.get(opts, :add?, false)
    replace_all? = Keyword.get(opts, :replace_all?, false)

    namespaces = namespaces_from_entries(entries)

    lines
    |> new_config_lines([], entries, namespaces, add?, replace_all?)
    |> reply_write_new_lines(path, of)
  catch
    :throw, :replacing_multivar ->
      cover {:reply, {:error, :replacing_multivar}, of}
  end

  defp reply_write_new_lines(lines, path, of) do
    config_text =
      lines
      |> Enum.map(& &1.original)
      |> Enum.join("\n")

    result = File.write(path, [config_text, "\n"])
    cover {:reply, result, of}
  end

  defp namespaces_from_entries(entries) do
    entries
    |> Enum.map(&namespace_from_entry/1)
    |> MapSet.new()
  end

  defp namespace_from_entry(%ConfigEntry{
         section: section,
         subsection: subsection,
         name: name
       }) do
    {section, subsection, name}
  end

  defp new_config_lines(
         remaining_old_lines,
         new_lines_acc,
         entries_to_add,
         namespaces,
         add?,
         replace_all?
       )

  defp new_config_lines(
         remaining_old_lines,
         new_lines_acc,
         [] = _entries_to_add,
         _namespaces,
         _add?,
         _replace_all?
       ) do
    new_lines_acc ++ remaining_old_lines
  end

  defp new_config_lines(
         remaining_old_lines,
         new_lines_acc,
         entries_to_add,
         namespaces,
         add?,
         replace_all?
       ) do
    {before_match, match_and_after} =
      Enum.split_while(remaining_old_lines, &(!matches_any_namespace?(&1, namespaces)))

    existing_lines = new_lines_acc ++ before_match
    last_existing_line = List.last(existing_lines)

    {new_lines, remaining_old_lines, entries_to_add} =
      new_lines(match_and_after, entries_to_add, last_existing_line, add?, replace_all?)

    new_config_lines(
      remaining_old_lines,
      existing_lines ++ new_lines,
      entries_to_add,
      namespaces,
      add?,
      replace_all?
    )
  end

  defp matches_any_namespace?(%__MODULE__.Line{entry: nil}, _namespaces), do: cover(false)

  defp matches_any_namespace?(
         %__MODULE__.Line{
           entry: %ConfigEntry{section: section, subsection: subsection, name: name}
         },
         namespaces
       ) do
    MapSet.member?(namespaces, {section, subsection, name})
  end

  defp new_lines(match_and_after, entries_to_add, last_existing_line, add?, replace_all?)

  defp new_lines(
         [
           %__MODULE__.Line{
             entry: %{
               section: section,
               subsection: subsection,
               name: name
             }
           }
           | _
         ] = match_and_after,
         entries_to_add,
         last_existing_line,
         add?,
         replace_all?
       ) do
    {replacing_lines, remaining_lines} =
      Enum.split_with(match_and_after, &matches_namespace?(&1, section, subsection, name))

    {matching_entries_to_add, other_entries_to_add} =
      Enum.split_with(entries_to_add, &matches_namespace?(&1, section, subsection, name))

    replacing_multivar? = Enum.count(replacing_lines) > 1

    existing_matches_to_keep =
      cond do
        replace_all? ->
          cover []

        add? ->
          cover replacing_lines

        replacing_multivar? ->
          throw(:replacing_multivar)

        # Yes, this is flow control via exception.
        # Not sure there is a clean way to avoid this.

        true ->
          cover []
      end

    new_lines =
      maybe_insert_subsection(last_existing_line, section, subsection) ++
        existing_matches_to_keep ++
        Enum.map(matching_entries_to_add, &entry_to_line/1)

    {new_lines, remaining_lines, other_entries_to_add}
  end

  defp new_lines(
         [] = _match_and_after,
         [
           %ConfigEntry{
             section: section,
             subsection: subsection,
             name: name
           }
           | _
         ] = entries_to_add,
         last_existing_line,
         _add?,
         _replace_all?
       ) do
    {matching_entries_to_add, other_entries_to_add} =
      Enum.split_with(entries_to_add, &matches_namespace?(&1, section, subsection, name))

    new_lines =
      maybe_insert_subsection(last_existing_line, section, subsection) ++
        Enum.map(matching_entries_to_add, &entry_to_line/1)

    cover {new_lines, [], other_entries_to_add}
  end

  defp matches_namespace?(
         %__MODULE__.Line{
           entry: %ConfigEntry{section: section, subsection: subsection, name: name}
         },
         section,
         subsection,
         name
       ),
       do: cover(true)

  defp matches_namespace?(
         %ConfigEntry{section: section, subsection: subsection, name: name},
         section,
         subsection,
         name
       ),
       do: cover(true)

  defp matches_namespace?(_line, _section, _subsection, _name), do: cover(false)

  defp maybe_insert_subsection(
         %__MODULE__.Line{section: section, subsection: subsection},
         section,
         subsection
       ),
       do: cover([])

  defp maybe_insert_subsection(_line, section, nil),
    do: cover([%__MODULE__.Line{original: "[#{section}]", section: section}])

  defp maybe_insert_subsection(_line, section, subsection) do
    escaped_subsection =
      subsection
      |> String.replace("\\", "\\\\")
      |> String.replace(~S("), ~S(\"))

    cover([
      %__MODULE__.Line{
        original: ~s([#{section} "#{escaped_subsection}"]),
        section: section,
        subsection: subsection
      }
    ])
  end

  defp entry_to_line(
         %ConfigEntry{section: section, subsection: subsection, name: name, value: value} = entry
       ) do
    escaped_value =
      value
      |> String.replace("\\", "\\\\")
      |> String.replace(~S("), ~S(\"))

    cover %__MODULE__.Line{
      entry: entry,
      original: "\t#{name} = #{escaped_value}",
      section: section,
      subsection: subsection
    }
  end

  @typedoc ~S"""
  Error codes that can be returned by `remove_entries/2`.
  """
  @type remove_entries_reason :: File.posix()

  @doc ~S"""
  Removes all configuration entries that match the requested search.

  ## Options

  * `section:` (`String`) if provided, only removes entries in the named section
  * `subsection:` (`String`) if provided, only removes entries in the named subsection
    (only meaningful if `section` is also provided)
  * `name:` (`String`) if provided, only removes entries with the given variable name
    (only meaningful if `section` is also provided)

  If `section` is provided but `subsection` is not, then only items within the top-level
  section (i.e. with no subsection) will be removed.

  If no options are provided, removes all entries.

  ## Return Values

  `:ok` if able to complete the operation (regardless of whether any matching entries
  were found and removed).

  `{:error, reason}` if unable. `reason` is likely a POSIX error code.
  """
  @spec remove_entries(config_file :: t,
          section: String.t(),
          subsection: String.t(),
          name: String.t()
        ) ::
          :ok | {:error, reason :: remove_entries_reason}
  def remove_entries(config_file, opts \\ []) when is_pid(config_file) and is_list(opts),
    do: GenServer.call(config_file, {:remove_entries, opts})

  defp handle_remove_entries(%ObservedFile{path: path} = of, []) do
    result = File.write(path, "")
    cover {:reply, result, of}
  end

  defp handle_remove_entries(%ObservedFile{path: path} = of, opts) when is_list(opts) do
    %{parsed_state: lines} =
      of = ObservedFile.update_state_if_maybe_dirty(of, &parse_config_at_path/1, &empty_config/0)

    opts = Enum.into(opts, %{})

    lines
    |> Enum.reject(&line_matches_opts?(&1, opts))
    |> reply_write_new_lines(path, of)
  end

  defp line_matches_opts?(
         %__MODULE__.Line{section: section, entry: %{name: name}} = line,
         %{section: section, name: name} = opts
       ),
       do: line.subsection == Map.get(opts, :subsection)

  defp line_matches_opts?(
         %__MODULE__.Line{section: section, entry: %{name: name1}} = _line,
         %{section: section, name: name2} = _opts
       )
       when is_binary(name1) and is_binary(name2),
       do: cover(false)

  defp line_matches_opts?(
         %__MODULE__.Line{section: section, subsection: subsection} = line,
         %{section: section, subsection: subsection} = opts
       ),
       do: line.subsection == Map.get(opts, :subsection)

  defp line_matches_opts?(_line, %{section: _section, name: name}) when not is_nil(name),
    do: cover(false)

  defp line_matches_opts?(%__MODULE__.Line{section: section} = line, %{section: section} = opts),
    do: line.subsection == Map.get(opts, :subsection)

  defp line_matches_opts?(_line, _opts), do: cover(false)

  @impl true
  def handle_call({:get_entries, opts}, _from, state), do: handle_get_entries(state, opts)

  def handle_call({:add_entries, entries, opts}, _from, state),
    do: handle_add_entries(state, entries, opts)

  def handle_call({:remove_entries, opts}, _from, state), do: handle_remove_entries(state, opts)

  def handle_call(message, _from, state) do
    Logger.warn("ConfigFile received unrecognized call #{inspect(message)}")
    {:reply, {:error, :unknown_message}, state}
  end
end
