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

defmodule Xgit.Core.ValidateObject do
  @moduledoc ~S"""
  Verifies that an object is formatted correctly.

  Verifications made by this module only check that the fields of an object are
  formatted correctly. The object ID checksum of the object is not verified, and
  connectivity links between objects are also not verified. It's assumed that
  the caller can provide both of these validations on its own.
  """

  alias Xgit.Core.FileMode
  alias Xgit.Core.Object
  alias Xgit.Core.ObjectId
  alias Xgit.Core.ValidatePath
  alias Xgit.Util.Paths
  alias Xgit.Util.RawParseUtils

  import Xgit.Util.RawParseUtils, only: [after_prefix: 2]

  @doc ~S"""
  Verify that a proposed object is valid.

  ## Options

  By default, this function will only enforce Posix file name restrictions.

  * `:macosx?`: `true` to also enforce Mac OS X file name restrictions
  * `:windows?`: `true` to also enforce Windows file name restrictions

  ## Return Value

  `:ok` if the object is successfully validated.

  `{:error, :invalid_type}` if the object's type is unknown.

  `{:error, :no_tree_header}` if the object is a commit but does not contain
  a valid tree header.

  `{:error, :invalid_tree}` if the object is a commit but the tree object ID
  is invalid.

  `{:error, :invalid_parent}` if the object is a commit but one of the `parent`
  headers is invalid.

  `{:error, :no_author}` if the object is a commit but there is no `author` header.

  `{:error, :no_committer}` if the object is a commit but there is no `committer` header.

  `{:error, :no_object_header}` if the object is a tag but there is no `object` header.

  `{:error, :invalid_object}` if the object is a tag but the object ID is invalid.

  `{:error, :no_type_header}` if the object is a tag but there is no `type` header.

  `{:error, :invalid_tagger}` if the object is a tag but one of the `tagger` headers
  is invalid.

  `{:error, :invalid_file_mode}` if the object is a tree but one of the file modes is invalid.

  `{:error, "reason"}` if the object can not be validated.
  """
  @spec check(object :: Object.t(), opts :: Keyword.t()) :: :ok | {:error, reason :: String.t()}
  def check(object, opts \\ [])

  def check(%Object{type: :blob}, _opts), do: :ok
  def check(%Object{type: :commit} = object, _opts), do: check_commit(object)
  def check(%Object{type: :tag} = object, _opts), do: check_tag(object)
  def check(%Object{type: :tree} = object, opts), do: check_tree(object, opts)
  def check(%Object{type: _type}, _opts), do: {:error, :invalid_type}

  # -- commit specifics --

  defp check_commit(%Object{content: data}) when is_list(data) do
    with {:tree, data} when is_list(data) <- {:tree, after_prefix(data, 'tree ')},
         {:tree_id, data} when is_list(data) <- {:tree_id, check_id(data)},
         {:parents, data} when is_list(data) <- {:parents, check_commit_parents(data)},
         {:author, data} when is_list(data) <- {:author, after_prefix(data, 'author ')},
         {:author_id, data} when is_list(data) <- {:author_id, check_person_ident(data)},
         {:committer, data} when is_list(data) <- {:committer, after_prefix(data, 'committer ')},
         {:committer_id, data} when is_list(data) <- {:committer_id, check_person_ident(data)} do
      :ok
    else
      {:tree, _} -> {:error, :no_tree_header}
      {:tree_id, _} -> {:error, :invalid_tree}
      {:parents, _} -> {:error, :invalid_parent}
      {:author, _} -> {:error, :no_author}
      {:author_id, why} when is_binary(why) -> {:error, why}
      {:committer, _} -> {:error, :no_committer}
      {:committer_id, why} when is_binary(why) -> {:error, why}
    end
  end

  defp check_commit_parents(data) do
    case after_prefix(data, 'parent ') do
      after_match when is_list(after_match) ->
        if next_line = check_id(after_match),
          do: check_commit_parents(next_line),
          else: nil

      nil ->
        data
    end
  end

  # -- tag specifics --

  defp check_tag(%Object{content: data}) when is_list(data) do
    with {:object, data} when is_list(data) <- {:object, after_prefix(data, 'object ')},
         {:object_id, data} when is_list(data) <- {:object_id, check_id(data)},
         {:type, data} when is_list(data) <- {:type, after_prefix(data, 'type ')},
         data <- RawParseUtils.next_lf(data),
         {:tag, data} when is_list(data) <- {:tag, after_prefix(data, 'tag ')},
         data <- RawParseUtils.next_lf(data),
         {:tagger, data} when is_list(data) <- {:tagger, maybe_match_tagger(data)} do
      :ok
    else
      {:object, _} -> {:error, :no_object_header}
      {:object_id, _} -> {:error, :invalid_object}
      {:type, _} -> {:error, :no_type_header}
      {:tag, _} -> {:error, :no_tag_header}
      {:tagger, _} -> {:error, :invalid_tagger}
    end
  end

  defp maybe_match_tagger(data) do
    after_match = after_prefix(data, 'tagger ')

    if is_list(after_match),
      do: check_person_ident(after_match),
      else: data
  end

  # -- tree specifics --

  defp check_tree(%Object{content: data}, opts) when is_list(data) and is_list(opts) do
    maybe_normalized_paths =
      if Keyword.get(opts, :windows?) || Keyword.get(opts, :macosx?),
        do: MapSet.new(),
        else: nil

    check_next_tree_entry(data, maybe_normalized_paths, [], FileMode.regular_file(), opts)
  end

  defp check_next_tree_entry([], _maybe_normalized_paths, _previous_name, _previous_mode, _opts),
    do: :ok

  defp check_next_tree_entry(data, maybe_normalized_paths, previous_name, previous_mode, opts) do
    # Scan one entry then recurse to scan remaining entries.

    with {:file_mode, {:ok, file_mode, data}} <- {:file_mode, check_file_mode(data, 0)},
         {:file_mode, true} <- {:file_mode, FileMode.valid?(file_mode)},
         {:path_split, {path_segment, [0 | data]}} <- {:path_split, path_and_object_id(data)},
         {:path_valid, :ok} <- {:path_valid, ValidatePath.check_path_segment(path_segment, opts)},
         {:duplicate, false} <-
           {:duplicate, maybe_mapset_member?(maybe_normalized_paths, path_segment, opts)},
         {:duplicate, false} <- {:duplicate, duplicate_name?(path_segment, data)},
         {:sorted, true} <-
           {:sorted, correctly_sorted?(previous_name, previous_mode, path_segment, file_mode)},
         {raw_object_id, data} <- Enum.split(data, 20),
         {:object_id_length, 20} <- {:object_id_length, Enum.count(raw_object_id)},
         {:object_id_null, false} <- {:object_id_null, Enum.all?(raw_object_id, &(&1 == 0))} do
      check_next_tree_entry(
        data,
        maybe_put_path(maybe_normalized_paths, path_segment, opts),
        path_segment,
        file_mode,
        opts
      )
    else
      {:file_mode, {:error, reason}} -> {:error, reason}
      {:file_mode, _} -> {:error, :invalid_file_mode}
      {:path_split, _} -> {:error, "truncated in name"}
      {:path_valid, {:error, reason}} -> {:error, reason}
      {:duplicate, _} -> {:error, "duplicate entry names"}
      {:sorted, _} -> {:error, "incorrectly sorted"}
      {:object_id_length, _} -> {:error, "truncated in object id"}
      {:object_id_null, _} -> {:error, "entry points to null SHA-1"}
    end
  end

  defp check_file_mode([], _mode), do: {:error, "truncated in mode"}

  defp check_file_mode([?\s | data], mode), do: {:ok, mode, data}

  defp check_file_mode([?0 | _data], 0), do: {:error, "mode starts with '0'"}

  defp check_file_mode([c | data], mode) when c >= ?0 and c <= ?7,
    do: check_file_mode(data, mode * 8 + (c - ?0))

  defp check_file_mode([_c | _data], _mode), do: {:error, "invalid mode character"}

  defp path_and_object_id(data), do: Enum.split_while(data, &(&1 != 0))

  defp maybe_mapset_member?(nil, _path_segment, _opts), do: false

  defp maybe_mapset_member?(mapset, path_segment, opts),
    do: MapSet.member?(mapset, normalize(path_segment, Keyword.get(opts, :macosx?, false)))

  defp duplicate_name?(this_name, data) do
    data = Enum.drop(data, 20)

    {mode_str, data} = Enum.split_while(data, &(&1 != ?\s))
    mode = parse_octal(mode_str)

    data = Enum.drop(data, 1)

    {next_name, data} = Enum.split_while(data, &(&1 != 0))

    data = Enum.drop(data, 1)

    compare = Paths.compare_same_name(this_name, next_name, mode)

    cond do
      Enum.empty?(mode_str) or Enum.empty?(next_name) -> false
      compare == :lt -> false
      compare == :eq -> true
      compare == :gt -> duplicate_name?(this_name, data)
    end
  end

  defp parse_octal(data) do
    case Integer.parse(to_string(data), 8) do
      {n, _} when is_integer(n) -> n
      :error -> 0
    end
  end

  defp correctly_sorted?(nil, _previous_mode, _this_name, _this_mode), do: true

  defp correctly_sorted?(previous_name, previous_mode, this_name, this_mode),
    do: Paths.compare(previous_name, previous_mode, this_name, this_mode) != :gt

  defp maybe_put_path(nil, _path_segment, _opts), do: nil

  defp maybe_put_path(mapset, path_segment, opts),
    do: MapSet.put(mapset, normalize(path_segment, Keyword.get(opts, :macosx?, false)))

  # -- generic matching utilities --

  defp check_id(data) do
    case ObjectId.from_hex_charlist(data) do
      {_id, [?\n | remainder]} -> remainder
      _ -> nil
    end
  end

  defp check_person_ident(data) do
    with {:missing_email, [?< | email_start]} <-
           {:missing_email, RawParseUtils.next_lf(data, ?<)},
         {:bad_email, [?> | after_email]} <- {:bad_email, RawParseUtils.next_lf(email_start, ?>)},
         {:missing_space_before_date, [?\s | date]} <- {:missing_space_before_date, after_email},
         {:bad_date, {_date, [?\s | tz]}} <- {:bad_date, RawParseUtils.parse_base_10(date)},
         {:bad_timezone, {_tz, [?\n | next]}} <- {:bad_timezone, RawParseUtils.parse_base_10(tz)} do
      next
    else
      {:missing_email, _} -> "missing email"
      {:bad_email, _} -> "bad email"
      {:missing_space_before_date, _} -> "missing space before date"
      {:bad_date, _} -> "bad date"
      {:bad_timezone, _} -> "bad time zone"
    end
  end

  defp normalize(name, true = _mac?) when is_list(name) do
    name
    |> RawParseUtils.decode()
    |> String.downcase()
    |> :unicode.characters_to_nfc_binary()
  end

  defp normalize(name, _) when is_list(name), do: Enum.map(name, &to_lower/1)

  defp to_lower(b) when b >= ?A and b <= ?Z, do: b + 32
  defp to_lower(b), do: b
end
