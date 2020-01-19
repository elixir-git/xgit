defmodule Xgit.Util.ObservedFile do
  @moduledoc false
  # Records the cached parsed state of the file and its modification date
  # so that Xgit can avoid the work of re-parsing that file when we can
  # be sure it is unchanged.

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  Cache for parsed state of the file and information about its
  file system state.

  ## Struct Members

  * `path`: path to the file
  * `exists?`: `true` if the file existed last time we checked
  * `last_modified_time`: POSIX file time for the file last time we checked
      (`nil` if file did not exist then)
  * `last_checked_time`: POSIX time stamp when file status was checked
      (used to help avoid the "racy git problem")
  * `parsed_state`: result from either `parse_fn` or `empty_fn`
  """
  @type t :: %__MODULE__{
          path: Path.t(),
          exists?: boolean,
          last_modified_time: integer | nil,
          last_checked_time: integer | nil,
          parsed_state: any
        }

  @typedoc ~S"""
  A function that parses a file at a given path and returns a parsed state
  for that file.
  """
  @type parse_fn :: (Path.t() -> any)

  @typedoc ~S"""
  A function that can return a state for the file format when the file
  doesn't exist.
  """
  @type empty_fn :: (() -> any)

  @enforce_keys [:path, :exists?, :parsed_state]
  defstruct [
    :path,
    :exists?,
    :last_modified_time,
    :last_checked_time,
    :parsed_state
  ]

  @doc ~S"""
  Record an initial observation of the contents of the file.

  ## Parameters

  `parse_fn` is a function with one argument (path) that parses the file
  if it exists and returns the content that will be stored in `parsed_state`.

  `empty_fn` is a function with zero arguments that returns the desired state
  for `parsed_state` in the event there is no file at this path.
  """
  @spec initial_state_for_path(path :: Path.t(), parse_fn :: parse_fn, empty_fn :: empty_fn) :: t
  def initial_state_for_path(path, parse_fn, empty_fn)
      when is_binary(path) and is_function(parse_fn, 1) and is_function(empty_fn, 0),
      do: state_from_file_stat(path, parse_fn, empty_fn, File.stat(path, time: :posix))

  defp state_from_file_stat(path, parse_fn, _empty_fn, {:ok, %{type: :regular, mtime: mtime}}) do
    %__MODULE__{
      path: path,
      exists?: true,
      last_modified_time: mtime,
      last_checked_time: System.os_time(:second),
      parsed_state: parse_fn.(path)
    }
  end

  defp state_from_file_stat(path, _parse_fn, _empty_fn, {:ok, %{type: file_type}}) do
    raise ArgumentError,
          "Xgit.Util.ObservedFile: path #{path} points to an item of type #{file_type}; should be a regular file or no file at all"
  end

  defp state_from_file_stat(path, _parse_fn, empty_fn, {:error, :enoent}) do
    %__MODULE__{
      path: path,
      exists?: false,
      parsed_state: empty_fn.()
    }
  end

  @doc ~S"""
  Return `true` if the file has potentially changed since the last
  recorded observation. This can happen if:

  * The modified time has changed since the previous observation.
  * The file exists when it did not previously exist (or vice versa).
  * The modified time is so recent as to be indistinguishable from
    the time at which the initial snapshot was recorded. (This is often
    referred to as the "racy git problem.")

  This function does not update the cached state of the file.
  """
  @spec maybe_dirty?(observed_file :: t) :: boolean
  def maybe_dirty?(%__MODULE__{path: path} = observed_file) when is_binary(path),
    do: maybe_dirty_for_file_stat?(observed_file, File.stat(path, time: :posix))

  defp maybe_dirty_for_file_stat?(
         %__MODULE__{
           exists?: true,
           last_modified_time: last_modified_time,
           last_checked_time: last_checked_time
         },
         {:ok, %File.Stat{type: :regular, mtime: last_modified_time}}
       )
       when is_integer(last_modified_time) do
    # File still exists and modified time is same as before. Are we in racy git state?
    # Certain file systems round to the nearest few seconds, so last mod time has
    # to be at least 3 seconds before we checked status for us to start believing file content.

    last_modified_time >= last_checked_time - 2
  end

  defp maybe_dirty_for_file_stat?(
         %__MODULE__{exists?: true, last_modified_time: lmt1},
         {:ok, %File.Stat{type: :regular, mtime: lmt2}}
       )
       when is_integer(lmt1) and is_integer(lmt2) do
    # File still exists but modified time doesn't match: Dirty.
    cover true
  end

  defp maybe_dirty_for_file_stat?(%__MODULE__{exists?: false}, {:error, :enoent}) do
    # File didn't exist before; still doesn't: Not dirty.
    cover false
  end

  defp maybe_dirty_for_file_stat?(%__MODULE__{exists?: false}, {:ok, %File.Stat{type: :regular}}) do
    # File didn't exist before; it does now.
    cover true
  end

  defp maybe_dirty_for_file_stat?(%__MODULE__{exists?: true}, {:error, :enoent}) do
    # File existed before; now it doesn't.
    cover true
  end

  defp maybe_dirty_for_file_stat?(%__MODULE__{path: path}, {:ok, %{type: file_type}}) do
    raise ArgumentError,
          "Xgit.Util.ObservedFile: path #{path} points to an item of type #{file_type}; should be a regular file or no file at all"
  end

  @doc ~S"""
  Update the cached state of the file if it has potentially changed since the last
  observation.

  As noted in `maybe_dirty?/1`, we err on the side of caution if the modification date
  alone can not be trusted to reflect changes to the file's content.

  ## Parameters

  `parse_fn` is a function with one argument (path) that parses the file
  if it exists and returns the content that will be stored in `parsed_state`.

  `empty_fn` is a function with zero arguments that returns the desired state
  for `parsed_state` in the event there is no file at this path.

  If the file state has potentially changed (see `maybe_dirty?/1`) then either
  `parse_fn` or `empty_fn` will be called to generate a new value for `parsed_state`.

  ## Return Value

  Returns an `ObservedFile` struct which may have been updated via either `parse_fn/1`
  or `empty_fn/0` as appropriate.
  """
  @spec update_state_if_maybe_dirty(
          observed_file :: t,
          parse_fn :: parse_fn,
          empty_fn :: empty_fn
        ) :: t
  def update_state_if_maybe_dirty(%__MODULE__{path: path} = observed_file, parse_fn, empty_fn)
      when is_binary(path) and is_function(parse_fn, 1) and is_function(empty_fn, 0) do
    file_stat = File.stat(path, time: :posix)

    if maybe_dirty_for_file_stat?(observed_file, file_stat) do
      state_from_file_stat(path, parse_fn, empty_fn, file_stat)
    else
      # We're sure the file is unchanged: Return cached state as is.
      cover observed_file
    end
  end
end
