# Copyright (C) 2008-2010, Google Inc.
# Copyright (C) 2008, Shawn O. Pearce <spearce@spearce.org>
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit/src/org/eclipse/jgit/lib/ObjectChecker.java
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

defmodule Xgit.Core.FilePath do
  @moduledoc ~S"""
  Describes a file path as stored in a git repo.

  Paths are always stored as a list of bytes. The git specification
  does not explicitly specify an encoding, but most commonly the
  path is interpreted as UTF-8.

  We use byte lists here to avoid confusion and possible misintepretation
  in Elixir's `String` type for non-UTF-8 paths.

  Paths are alternately referred to in git as "file name," "path,"
  "path name," and "object name." We're using the name `FilePath`
  to avoid collision with Elixir's built-in `Path` module and to make
  it clear that we're talking about the path to where a file is stored
  on disk.
  """

  @typedoc """
  Representation of a file's path within a git repo.

  Typically, though not necessarily, interpreted as UTF-8.
  """
  @type t :: [byte]

  @typedoc ~S"""
  Error codes which can be returned by `check_path/2`.
  """
  @type check_path_reason ::
          :invalid_name | :empty_path | :absolute_path | :duplicate_slash | :trailing_slash

  @typedoc ~S"""
  Error codes which can be returned by `check_path_segment/2`.
  """
  @type check_path_segment_reason ::
          :invalid_name
          | :empty_name
          | :reserved_name
          | :invalid_utf8_sequence
          | :invalid_name_on_windows
          | :windows_device_name

  @doc ~S"""
  Check the provided path to see if it is a valid path within a git repository.

  The rules enforced here are slightly different from what is allowed in a `tree`
  object in that we allow `/` characters to build hierarchical paths.

  ## Parameters

  `path` is a UTF-8 byte list containing the path to be tested.

  ## Options

  * `windows?`: `true` to additionally verify that the path is permissible on Windows file systems
  * `macosx?`: `true` to additionally verify that the path is permissible on Mac OS X file systems

  ## Return Values

  * `:ok` if the name is permissible given the constraints chosen above
  * `{:error, :invalid_name}` if the name is not permissible
  * `{:error, :empty_path}` if the name is empty
  * `{:error, :absolute_path}` if the name starts with a `/`
  * `{:error, :duplicate_slash}` if the name contains two `/` characters in a row
  * `{:error, :trailing_slash}` if the name contains a trailing `/`

  See also: error return values from `check_path_segment/2`.
  """
  @spec check_path(path :: [byte], windows?: boolean, macosx?: boolean) ::
          :ok | {:error, check_path_reason} | {:error, check_path_segment_reason}
  def check_path(path, opts \\ [])

  def check_path([], opts) when is_list(opts), do: {:error, :empty_path}
  def check_path([?/ | _], opts) when is_list(opts), do: {:error, :absolute_path}

  def check_path(path, opts) when is_list(path) and is_list(opts) do
    {first_segment, remaining_path} = Enum.split_while(path, &(&1 != ?/))

    case check_path_segment(first_segment, opts) do
      :ok -> check_remaining_path(remaining_path, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_remaining_path([], _opts), do: :ok

  defp check_remaining_path([?/], _opts),
    do: {:error, :trailing_slash}

  defp check_remaining_path([?/, ?/ | _remainder], _opts),
    do: {:error, :duplicate_slash}

  defp check_remaining_path([?/ | remainder], opts), do: check_path(remainder, opts)

  @doc ~S"""
  Check the provided path segment to see if it is a valid path within a git `tree`
  object.

  ## Parameters

  `path` is a UTF-8 byte list containing the path segment to be tested.

  ## Options

  * `windows?`: `true` to additionally verify that the path is permissible on Windows file systems
  * `macosx?`: `true` to additionally verify that the path is permissible on Mac OS X file systems

  ## Return Values

  * `:ok` if the name is permissible given the constraints chosen above
  * `{:error, :invalid_name}` if the name is not permissible
  * `{:error, :empty_name}` if the name is empty
  * `{:error, :reserved_name}` if the name is reserved for git's use (i.e. `.git`)
  * `{:error, :invalid_utf8_sequence}` if the name contains certain incomplete UTF-8 byte sequences
    (only when `macosx?: true` is selected)
  * `{:error, :invalid_name_on_windows}` if the name contains characters that are
     not allowed on Windows file systems (only when `windows?: true` is selected)
  * `{:error, :windows_device_name}` if the name matches a Windows device name (`aux`, etc.)
    (only when `windows?: true` is selected)
  """
  @spec check_path_segment(path :: [byte], windows?: boolean, macosx?: boolean) ::
          :ok | {:error, check_path_segment_reason}
  def check_path_segment(path, opts \\ [])

  def check_path_segment([], opts) when is_list(opts), do: {:error, :empty_name}

  def check_path_segment(path_segment, opts) when is_list(path_segment) and is_list(opts) do
    windows? = Keyword.get(opts, :windows?, false)
    macosx? = Keyword.get(opts, :macosx?, false)

    with :ok <- refute_has_nil_bytes(path_segment),
         :ok <- refute_has_slash(path_segment),
         :ok <- check_windows_git_name(path_segment),
         :ok <- check_windows_characters(path_segment, windows?),
         :ok <- check_git_special_name(path_segment),
         :ok <- check_git_path_with_mac_ignorables(path_segment, macosx?),
         :ok <- check_truncated_utf8_for_mac(path_segment, macosx?),
         :ok <- check_illegal_windows_name_ending(path_segment, windows?),
         :ok <- check_windows_device_name(path_segment, windows?) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp refute_has_nil_bytes(path_segment) do
    if Enum.any?(path_segment, &(&1 == 0)),
      do: {:error, :invalid_name},
      else: :ok
  end

  defp refute_has_slash(path_segment) do
    if Enum.any?(path_segment, &(&1 == ?/)),
      do: {:error, :invalid_name},
      else: :ok
  end

  defp check_windows_git_name(path_segment) do
    with 5 <- Enum.count(path_segment),
         'git~1' <- Enum.map(path_segment, &to_lower/1) do
      {:error, :invalid_name}
    else
      _ -> :ok
    end
  end

  defp check_windows_characters(_path_segment, false = _windows?), do: :ok

  defp check_windows_characters(path_segment, true = _windows?) do
    case Enum.find(path_segment, &invalid_on_windows?/1) do
      nil -> :ok
      _ -> {:error, :invalid_name_on_windows}
    end
  end

  defp invalid_on_windows?(?"), do: true
  defp invalid_on_windows?(?*), do: true
  defp invalid_on_windows?(?:), do: true
  defp invalid_on_windows?(?<), do: true
  defp invalid_on_windows?(?>), do: true
  defp invalid_on_windows?(??), do: true
  defp invalid_on_windows?(?\\), do: true
  defp invalid_on_windows?(?|), do: true
  defp invalid_on_windows?(c) when c >= 1 and c <= 31, do: true
  defp invalid_on_windows?(_), do: false

  defp check_git_special_name('.'), do: {:error, :reserved_name}
  defp check_git_special_name('..'), do: {:error, :reserved_name}
  defp check_git_special_name('.git'), do: {:error, :reserved_name}

  defp check_git_special_name([?. | rem] = _name) do
    if normalized_git?(rem),
      do: {:error, :reserved_name},
      else: :ok
  end

  defp check_git_special_name(_), do: :ok

  defp normalized_git?(name) do
    if git_name_prefix?(name) do
      name
      |> Enum.drop(3)
      |> valid_git_suffix?()
    else
      false
    end
  end

  # The simpler approach would be to convert this to a string and use
  # String.downcase/1 on it. But that would create a lot of garbage to collect.
  # This approach is a bit more cumbersome, but more efficient.
  defp git_name_prefix?([?g | it]), do: it_name_prefix?(it)
  defp git_name_prefix?([?G | it]), do: it_name_prefix?(it)
  defp git_name_prefix?(_), do: false

  defp it_name_prefix?([?i | it]), do: t_name_prefix?(it)
  defp it_name_prefix?([?I | it]), do: t_name_prefix?(it)
  defp it_name_prefix?(_), do: false

  defp t_name_prefix?([?t | _]), do: true
  defp t_name_prefix?([?T | _]), do: true
  defp t_name_prefix?(_), do: false

  defp valid_git_suffix?([]), do: true
  defp valid_git_suffix?(' '), do: true
  defp valid_git_suffix?('.'), do: true
  defp valid_git_suffix?('. '), do: true
  defp valid_git_suffix?(' .'), do: true
  defp valid_git_suffix?(' . '), do: true
  defp valid_git_suffix?(_), do: false

  defp check_git_path_with_mac_ignorables(_path_segment, false = _macosx?), do: :ok

  defp check_git_path_with_mac_ignorables(path_segment, true = _macosx?) do
    if match_mac_hfs_path?(path_segment, '.git'),
      do: {:error, :reserved_name},
      else: :ok
  end

  defp check_truncated_utf8_for_mac(_path_segment, false = _macosx?), do: :ok

  defp check_truncated_utf8_for_mac(path_segment, true = _macosx?) do
    tail3 = Enum.slice(path_segment, -2, 2)

    if Enum.any?(tail3, &(&1 == 0xE2 or &1 == 0xEF)),
      do: {:error, :invalid_utf8_sequence},
      else: :ok
  end

  defp check_illegal_windows_name_ending(_path_segment, false = _windows?), do: :ok

  defp check_illegal_windows_name_ending(path_segment, true = _windows?) do
    last_char = List.last(path_segment)

    if last_char == ?\s || last_char == ?.,
      do: {:error, :invalid_name_on_windows},
      else: :ok
  end

  defp check_windows_device_name(_path_segment, false = _windows?), do: :ok

  defp check_windows_device_name(path_segment, true = _windows?) do
    lc_name =
      path_segment
      |> Enum.map(&to_lower/1)
      |> Enum.take_while(&(&1 != ?.))

    if windows_device_name?(lc_name),
      do: {:error, :windows_device_name},
      else: :ok
  end

  defp windows_device_name?('aux'), do: true
  defp windows_device_name?('con'), do: true
  defp windows_device_name?('com' ++ [d]), do: positive_digit?(d)
  defp windows_device_name?('lpt' ++ [d]), do: positive_digit?(d)
  defp windows_device_name?('nul'), do: true
  defp windows_device_name?('prn'), do: true
  defp windows_device_name?(_), do: false

  defp positive_digit?(b) when b >= ?1 and b <= ?9, do: true
  defp positive_digit?(_), do: false

  @doc ~S"""
  Return `true` if the filename _could_ be read as a `.gitmodules` file when
  checked out to the working directory.

  This would seem like a simple comparison, but some filesystems have peculiar
  rules for normalizing filenames:

  NTFS has backward-compatibility support for 8.3 synonyms of long file
  names. (See
  https://web.archive.org/web/20160318181041/https://usn.pw/blog/gen/2015/06/09/filenames/
  for details.) NTFS is also case-insensitive.

  MacOS's HFS+ folds away ignorable Unicode characters in addition to case
  folding.

  ## Parameters

  `path` is a UTF-8 byte list containing the path to be tested.

  ## Options

  By default, this function will only check for the plain `.gitmodules` name.

  * `windows?`: `true` to additionally check for any path that might be treated
    as a `.gitmodules` file on Windows file systems
  * `macosx?`: `true` to additionally check for any path that might be treated
    as a `.gitmodules` file on Mac OS X file systems
  """
  @spec gitmodules?(path :: [byte], windows?: boolean, macosx?: boolean) :: boolean
  def gitmodules?(path, opts \\ [])

  def gitmodules?('.gitmodules', opts) when is_list(opts), do: true

  def gitmodules?(path, opts) when is_list(opts) do
    (Keyword.get(opts, :windows?, false) and ntfs_gitmodules?(path)) or
      (Keyword.get(opts, :macosx?, false) and mac_hfs_gitmodules?(path))
  end

  defp ntfs_gitmodules?(name) do
    case Enum.count(name) do
      8 -> ntfs_shortened_gitmodules?(Enum.map(name, &to_lower(&1)))
      11 -> Enum.map(name, &to_lower(&1)) == '.gitmodules'
      _ -> false
    end
  end

  defp ntfs_shortened_gitmodules?('gitmod~' ++ rem), do: ntfs_numeric_suffix?(rem)
  defp ntfs_shortened_gitmodules?('gi7eba~' ++ rem), do: ntfs_numeric_suffix?(rem)
  defp ntfs_shortened_gitmodules?('gi7eb~' ++ rem), do: ntfs_numeric_suffix?(rem)
  defp ntfs_shortened_gitmodules?('gi7e~' ++ rem), do: ntfs_numeric_suffix?(rem)
  defp ntfs_shortened_gitmodules?('gi7~' ++ rem), do: ntfs_numeric_suffix?(rem)
  defp ntfs_shortened_gitmodules?('gi~' ++ rem), do: ntfs_numeric_suffix?(rem)
  defp ntfs_shortened_gitmodules?('g~' ++ rem), do: ntfs_numeric_suffix?(rem)
  defp ntfs_shortened_gitmodules?('~' ++ rem), do: ntfs_numeric_suffix?(rem)
  defp ntfs_shortened_gitmodules?(_), do: false

  # The first digit of the numeric suffix must not be zero.
  defp ntfs_numeric_suffix?([?0 | _rem]), do: false
  defp ntfs_numeric_suffix?(rem), do: ntfs_numeric_suffix_zero_ok?(rem)

  defp ntfs_numeric_suffix_zero_ok?([c | rem]) when c >= ?0 and c <= ?9,
    do: ntfs_numeric_suffix_zero_ok?(rem)

  defp ntfs_numeric_suffix_zero_ok?([]), do: true
  defp ntfs_numeric_suffix_zero_ok?(_), do: false

  defp mac_hfs_gitmodules?(path), do: match_mac_hfs_path?(path, '.gitmodules')

  # http://www.utf8-chartable.de/unicode-utf8-table.pl?start=8192
  defp match_mac_hfs_path?(data, match, ignorable? \\ false)

  # U+200C 0xe2808c ZERO WIDTH NON-JOINER
  defp match_mac_hfs_path?([0xE2, 0x80, 0x8C | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+200D 0xe2808d ZERO WIDTH JOINER
  defp match_mac_hfs_path?([0xE2, 0x80, 0x8D | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+200E 0xe2808e LEFT-TO-RIGHT MARK
  defp match_mac_hfs_path?([0xE2, 0x80, 0x8E | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+200F 0xe2808f RIGHT-TO-LEFT MARK
  defp match_mac_hfs_path?([0xE2, 0x80, 0x8F | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+202A 0xe280aa LEFT-TO-RIGHT EMBEDDING
  defp match_mac_hfs_path?([0xE2, 0x80, 0xAA | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+202B 0xe280ab RIGHT-TO-LEFT EMBEDDING
  defp match_mac_hfs_path?([0xE2, 0x80, 0xAB | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+202C 0xe280ac POP DIRECTIONAL FORMATTING
  defp match_mac_hfs_path?([0xE2, 0x80, 0xAC | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+202D 0xe280ad LEFT-TO-RIGHT OVERRIDE
  defp match_mac_hfs_path?([0xE2, 0x80, 0xAD | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+202E 0xe280ae RIGHT-TO-LEFT OVERRIDE
  defp match_mac_hfs_path?([0xE2, 0x80, 0xAE | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  defp match_mac_hfs_path?([0xE2, 0x80, _ | _], _match, _ignorable?), do: false

  # U+206A 0xe281aa INHIBIT SYMMETRIC SWAPPING
  defp match_mac_hfs_path?([0xE2, 0x81, 0xAA | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+206B 0xe281ab ACTIVATE SYMMETRIC SWAPPING
  defp match_mac_hfs_path?([0xE2, 0x81, 0xAB | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+206C 0xe281ac INHIBIT ARABIC FORM SHAPING
  defp match_mac_hfs_path?([0xE2, 0x81, 0xAC | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+206D 0xe281ad ACTIVATE ARABIC FORM SHAPING
  defp match_mac_hfs_path?([0xE2, 0x81, 0xAD | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+206E 0xe281ae NATIONAL DIGIT SHAPES
  defp match_mac_hfs_path?([0xE2, 0x81, 0xAE | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  # U+206F 0xe281af NOMINAL DIGIT SHAPES
  defp match_mac_hfs_path?([0xE2, 0x81, 0xAF | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  defp match_mac_hfs_path?([0xE2, 0x81, _ | _], _match, _ignorable?), do: false

  defp match_mac_hfs_path?([0xEF, 0xBB, 0xBF | data], match, _ignorable?),
    do: match_mac_hfs_path?(data, match, true)

  defp match_mac_hfs_path?([0xEF, _, _ | _], _match, _ignorable?), do: false

  defp match_mac_hfs_path?([c | _] = _list, _match, _ignorable?)
       when c == 0xE2 or c == 0xEF,
       do: false

  defp match_mac_hfs_path?([c | data], [m | match], ignorable?) do
    if to_lower(c) == m,
      do: match_mac_hfs_path?(data, match, ignorable?),
      else: false
  end

  defp match_mac_hfs_path?([], [], _ignorable?), do: true
  # defp match_mac_hfs_path?([], [], ignorable?), do: ignorable?
  # TO DO: Understand what jgit was trying to accomplish with ignorable.
  # https://github.com/elixir-git/xgit/issues/34

  defp match_mac_hfs_path?(_data, _match, _ignorable?), do: false

  defp to_lower(b) when b >= ?A and b <= ?Z, do: b + 32
  defp to_lower(b), do: b
end
