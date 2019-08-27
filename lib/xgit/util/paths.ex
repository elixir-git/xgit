# Copyright (C) 2016, 2018 Google Inc.
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit/src/org/eclipse/jgit/util/Paths.java
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

defmodule Xgit.Util.Paths do
  @moduledoc ~S"""
  Utility functions for comparing paths inside of a git repository.
  """

  use Bitwise
  use Xgit.Core.FileMode

  alias Xgit.Util.Comparison

  @doc ~S"""
  Remove trailing `/` if present.
  """
  @spec strip_trailing_separator(path :: charlist) :: charlist
  def strip_trailing_separator([]), do: []

  def strip_trailing_separator(path) when is_list(path) do
    if List.last(path) == ?/ do
      path
      |> Enum.reverse()
      |> Enum.drop_while(&(&1 == ?/))
      |> Enum.reverse()
    else
      path
    end
  end

  @doc ~S"""
  Compare two paths according to git path sort ordering rules.

  ## Return Value

  * `:lt` if `path1` sorts before `path2`.
  * `:eq` if they are the same.
  * `:gt` if `path1` sorts after `path2`.
  """
  @spec compare(
          path1 :: charlist,
          mode1 :: FileMode.t(),
          path2 :: charlist,
          mode2 :: FileMode.t()
        ) :: Comparison.result()
  def compare(path1, mode1, path2, mode2)
      when is_list(path1) and is_file_mode(mode1) and is_list(path2) and is_file_mode(mode2) do
    case core_compare(path1, mode1, path2, mode2) do
      :eq -> mode_compare(mode1, mode2)
      x -> x
    end
  end

  @doc ~S"""
  Compare two paths, checking for identical name.

  Unlike `compare/4`, this method returns `:eq` when the paths have
  the same characters in their names, even if the mode differs. It is
  intended for use in validation routines detecting duplicate entries.

  ## Parameters

  `mode2` is the mode of the second file. Trees are sorted as though
  `List.last(path2) == ?/`, even if no such character exists.
  Return `:lt` if no duplicate name could exist; `:eq` if the paths
  have the same name; `:gt` if other `path2` should still be checked
  by caller.

  ## Return Value

  Returns `:eq` if the names are identical and a conflict exists
  between `path1` and `path2`, as they share the same name.

  Returns `:lt` if all possible occurrences of `path1` sort
  before `path2` and no conflict can happen. In a properly sorted
  tree there are no other occurrences of `path1` and therefore there
  are no duplicate names.

  Returns `:gt` when it is possible for a duplicate occurrence of
  `path1` to appear later, after `path2`. Callers should
  continue to examine candidates for `path2` until the method returns
  one of the other return values.
  """
  @spec compare_same_name(path1 :: charlist, path2 :: charlist, mode2 :: FileMode.t()) ::
          Comparison.result()
  def compare_same_name(path1, path2, mode2),
    do: core_compare(path1, FileMode.tree(), path2, mode2)

  defp core_compare(path1, mode1, path2, mode2)

  defp core_compare([c | rem1], mode1, [c | rem2], mode2),
    do: core_compare(rem1, mode1, rem2, mode2)

  defp core_compare([c1 | _rem1], _mode1, [c2 | _rem2], _mode2),
    do: compare_chars(c1, c2)

  defp core_compare([c1 | _rem1], _mode1, [], mode2),
    do: compare_chars(band(c1, 0xFF), last_path_char(mode2))

  defp core_compare([], mode1, [c2 | _], _mode2),
    do: compare_chars(last_path_char(mode1), band(c2, 0xFF))

  defp core_compare([], _mode1, [], _mode2), do: :eq

  defp compare_chars(c, c), do: :eq
  defp compare_chars(c1, c2) when c1 < c2, do: :lt
  defp compare_chars(_, _), do: :gt

  defp last_path_char(mode) do
    if FileMode.tree?(mode),
      do: ?/,
      else: 0
  end

  defp mode_compare(mode1, mode2) do
    if FileMode.gitlink?(mode1) or FileMode.gitlink?(mode2),
      do: :eq,
      else: compare_chars(last_path_char(mode1), last_path_char(mode2))
  end
end
