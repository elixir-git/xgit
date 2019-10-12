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

defmodule Xgit.Core.Object do
  @moduledoc ~S"""
  Describes a single object stored (or about to be stored) in a git repository.

  This struct is constructed, modified, and shared as a working description of
  how to find and describe an object before it gets written to a repository.
  """
  use Xgit.Core.ObjectType

  alias Xgit.Core.ContentSource
  alias Xgit.Core.FileMode
  alias Xgit.Core.FilePath
  alias Xgit.Core.ObjectId
  alias Xgit.Util.ParseDecimal
  alias Xgit.Util.RawParseUtils

  import Xgit.Util.ForceCoverage
  import Xgit.Util.RawParseUtils, only: [after_prefix: 2]

  @typedoc ~S"""
  This struct describes a single object stored or about to be stored in a git
  repository.

  ## Struct Members

  * `:type`: the object's type (`:blob`, `:tree`, `:commit`, or `:tag`)
  * `:content`: how to obtain the content (see `Xgit.Core.ContentSource`)
  * `:size`: size (in bytes) of the object or `:unknown`
  * `:id`: object ID (40 chars hex) of the object or `:unknown`
  """
  @type t :: %__MODULE__{
          type: ObjectType.t(),
          content: ContentSource.t(),
          size: non_neg_integer() | :unknown,
          id: ObjectId.t() | :unknown
        }

  @enforce_keys [:type, :content]
  defstruct [:type, :content, size: :unknown, id: :unknown]

  @doc ~S"""
  Return `true` if the struct describes a valid object.

  _IMPORTANT:_ This validation _only_ verifies that the struct itself is valid.
  It does not inspect the content of the object. That check can be performed by
  `check/2`.
  """
  @spec valid?(object :: any) :: boolean
  def valid?(object)

  def valid?(%__MODULE__{type: type, content: content, size: size, id: id})
      when is_object_type(type) and is_integer(size) and size >= 0,
      do: ObjectId.valid?(id) && content != nil && ContentSource.impl_for(content) != nil

  def valid?(_), do: cover(false)

  @typedoc ~S"""
  Error codes which can be returned by `check/2`.
  """
  @type check_reason ::
          :invalid_type
          | :no_tree_header
          | :invalid_tree
          | :invalid_parent
          | :no_author
          | :no_committer
          | :no_object_header
          | :invalid_object
          | :no_type_header
          | :invalid_tagger
          | :bad_date
          | :bad_email
          | :missing_email
          | :missing_space_before_date
          | :bad_time_zone
          | :invalid_file_mode
          | :truncated_in_name
          | :duplicate_entry_names
          | :incorrectly_sorted
          | :truncated_in_object_id
          | :null_sha1
          | :invalid_mode

  @doc ~S"""
  Verify that a proposed object is valid.

  This function performs a detailed check on the _content_ of the object.
  For a simpler verification that the `Object` struct is _itself_
  valid, see `valid?/1`.

  Verifications made by this function only check that the fields of an object are
  formatted correctly. The object ID checksum of the object is not verified, and
  connectivity links between objects are also not verified. It's assumed that
  the caller can provide both of these validations on its own.

  ## Options

  By default, this function will only enforce Posix file name restrictions.

  * `:macosx?`: `true` to also enforce Mac OS X path name restrictions
  * `:windows?`: `true` to also enforce Windows path name restrictions

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

  `{:error, :bad_date}` if the object is a tag or a commit but has a malformed date entry.

  `{:error, :bad_email}` if the object is a tag or a commit but has a malformed e-mail address.

  `{:error, :missing_email}` if the object is a tag or a commit but has a missing e-mail address
  where one is expected.

  `{:error, :missing_space_before_date}` if the object is a tag or a commit but
  has no space preceding the place where a date is expected.

  `{:error, :bad_time_zone}` if the object is a tag or a commit but has a malformed
  time zone entry.

  `{:error, :invalid_file_mode}` if the object is a tree but one of the file modes is invalid.

  `{:error, :truncated_in_name}` if the object is a tree but one of the file names is incomplete.

  `{:error, :duplicate_entry_names}` if the object is a tree and contains duplicate
  entry names.

  `{:error, :incorrectly_sorted}` if the object is a tree and the entries are not
  in alphabetical order.

  `{:error, :truncated_in_object_id}` if the object is a tree and one of the object IDs
  is invalid.

  `{:error, :null_sha1}` if the object is a tree and one of the object IDs is all zeros.

  `{:error, :invalid_mode}` if the object is a tree and one of the file modes is incomplete.

  See also error responses from `Xgit.Core.FilePath.check_path/2` and
  `Xgit.Core.FilePath.check_path_segment/2`.
  """
  @spec check(object :: t(), windows?: boolean, macosx?: boolean) ::
          :ok
          | {:error, reason :: check_reason}
          | {:error, reason :: FilePath.check_path_reason()}
          | {:error, reason :: FilePath.check_path_segment_reason()}
  def check(object, opts \\ [])

  def check(%__MODULE__{type: :blob}, _opts), do: cover(:ok)
  def check(%__MODULE__{type: :commit} = object, _opts), do: check_commit(object)
  def check(%__MODULE__{type: :tag} = object, _opts), do: check_tag(object)
  def check(%__MODULE__{type: :tree} = object, opts), do: check_tree(object, opts)
  def check(%__MODULE__{type: _type}, _opts), do: cover({:error, :invalid_type})

  # -- commit specifics --

  defp check_commit(%__MODULE__{content: data}) when is_list(data) do
    with {:tree, data} when is_list(data) <- {:tree, after_prefix(data, 'tree ')},
         {:tree_id, data} when is_list(data) <- {:tree_id, check_id(data)},
         {:parents, data} when is_list(data) <- {:parents, check_commit_parents(data)},
         {:author, data} when is_list(data) <- {:author, after_prefix(data, 'author ')},
         {:author_id, data} when is_list(data) <- {:author_id, check_person_ident(data)},
         {:committer, data} when is_list(data) <- {:committer, after_prefix(data, 'committer ')},
         {:committer_id, data} when is_list(data) <- {:committer_id, check_person_ident(data)} do
      cover :ok
    else
      {:tree, _} -> cover {:error, :no_tree_header}
      {:tree_id, _} -> cover {:error, :invalid_tree}
      {:parents, _} -> cover {:error, :invalid_parent}
      {:author, _} -> cover {:error, :no_author}
      {:author_id, why} when is_atom(why) -> cover {:error, why}
      {:committer, _} -> cover {:error, :no_committer}
      {:committer_id, why} when is_atom(why) -> cover {:error, why}
    end
  end

  defp check_commit_parents(data) do
    case after_prefix(data, 'parent ') do
      after_match when is_list(after_match) ->
        if next_line = check_id(after_match) do
          check_commit_parents(next_line)
        else
          cover nil
        end

      nil ->
        cover data
    end
  end

  # -- tag specifics --

  defp check_tag(%__MODULE__{content: data}) when is_list(data) do
    with {:object, data} when is_list(data) <- {:object, after_prefix(data, 'object ')},
         {:object_id, data} when is_list(data) <- {:object_id, check_id(data)},
         {:type, data} when is_list(data) <- {:type, after_prefix(data, 'type ')},
         data <- RawParseUtils.next_lf(data),
         {:tag, data} when is_list(data) <- {:tag, after_prefix(data, 'tag ')},
         data <- RawParseUtils.next_lf(data),
         {:tagger, data} when is_list(data) <- {:tagger, maybe_match_tagger(data)} do
      cover :ok
    else
      {:object, _} -> cover {:error, :no_object_header}
      {:object_id, _} -> cover {:error, :invalid_object}
      {:type, _} -> cover {:error, :no_type_header}
      {:tag, _} -> cover {:error, :no_tag_header}
      {:tagger, _} -> cover {:error, :invalid_tagger}
    end
  end

  defp maybe_match_tagger(data) do
    after_match = after_prefix(data, 'tagger ')

    if is_list(after_match) do
      check_person_ident(after_match)
    else
      cover data
    end
  end

  # -- tree specifics --

  defp check_tree(%__MODULE__{content: data}, opts) when is_list(data) and is_list(opts) do
    maybe_normalized_paths =
      if Keyword.get(opts, :windows?) || Keyword.get(opts, :macosx?) do
        MapSet.new()
      else
        cover nil
      end

    check_next_tree_entry(data, maybe_normalized_paths, [], FileMode.regular_file(), opts)
  end

  defp check_next_tree_entry([], _maybe_normalized_paths, _previous_name, _previous_mode, _opts),
    do: cover(:ok)

  defp check_next_tree_entry(data, maybe_normalized_paths, previous_name, previous_mode, opts) do
    # Scan one entry then recurse to scan remaining entries.

    with {:file_mode, {:ok, file_mode, data}} <- {:file_mode, check_file_mode(data, 0)},
         {:file_mode, true} <- {:file_mode, FileMode.valid?(file_mode)},
         {:path_split, {path_segment, [0 | data]}} <- {:path_split, path_and_object_id(data)},
         {:path_valid, :ok} <- {:path_valid, FilePath.check_path_segment(path_segment, opts)},
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
      {:file_mode, {:error, reason}} -> cover {:error, reason}
      {:file_mode, _} -> cover {:error, :invalid_file_mode}
      {:path_split, _} -> cover {:error, :truncated_in_name}
      {:path_valid, {:error, reason}} -> cover {:error, reason}
      {:duplicate, _} -> cover {:error, :duplicate_entry_names}
      {:sorted, _} -> cover {:error, :incorrectly_sorted}
      {:object_id_length, _} -> cover {:error, :truncated_in_object_id}
      {:object_id_null, _} -> cover {:error, :null_sha1}
    end
  end

  defp check_file_mode([], _mode), do: cover({:error, :invalid_mode})

  defp check_file_mode([?\s | data], mode), do: cover({:ok, mode, data})

  defp check_file_mode([?0 | _data], 0), do: cover({:error, :invalid_mode})

  defp check_file_mode([c | data], mode) when c >= ?0 and c <= ?7,
    do: check_file_mode(data, mode * 8 + (c - ?0))

  defp check_file_mode([_c | _data], _mode), do: cover({:error, :invalid_mode})

  defp path_and_object_id(data), do: Enum.split_while(data, &(&1 != 0))

  defp maybe_mapset_member?(nil, _path_segment, _opts), do: cover(false)

  defp maybe_mapset_member?(mapset, path_segment, opts),
    do: MapSet.member?(mapset, normalize(path_segment, Keyword.get(opts, :macosx?, false)))

  defp duplicate_name?(this_name, data) do
    data = Enum.drop(data, 20)

    {mode_str, data} = Enum.split_while(data, &(&1 != ?\s))
    mode = parse_octal(mode_str)

    data = Enum.drop(data, 1)

    {next_name, data} = Enum.split_while(data, &(&1 != 0))

    data = Enum.drop(data, 1)

    compare = FilePath.compare_same_name(this_name, next_name, mode)

    cond do
      Enum.empty?(mode_str) or Enum.empty?(next_name) -> cover false
      compare == :lt -> cover false
      compare == :eq -> cover true
      compare == :gt -> duplicate_name?(this_name, data)
    end
  end

  defp parse_octal(data) do
    case Integer.parse(to_string(data), 8) do
      {n, _} when is_integer(n) -> cover n
      :error -> cover 0
    end
  end

  defp correctly_sorted?([], _previous_mode, _this_name, _this_mode), do: cover(true)

  defp correctly_sorted?(previous_name, previous_mode, this_name, this_mode),
    do: FilePath.compare(previous_name, previous_mode, this_name, this_mode) != :gt

  defp maybe_put_path(nil, _path_segment, _opts), do: cover(nil)

  defp maybe_put_path(mapset, path_segment, opts),
    do: MapSet.put(mapset, normalize(path_segment, Keyword.get(opts, :macosx?, false)))

  # -- generic matching utilities --

  defp check_id(data) do
    case ObjectId.from_hex_charlist(data) do
      {_id, [?\n | remainder]} -> cover remainder
      _ -> cover nil
    end
  end

  defp check_person_ident(data) do
    with {:missing_email, [?< | email_start]} <-
           {:missing_email, RawParseUtils.next_lf(data, ?<)},
         {:bad_email, [?> | after_email]} <- {:bad_email, RawParseUtils.next_lf(email_start, ?>)},
         {:missing_space_before_date, [?\s | date]} <- {:missing_space_before_date, after_email},
         {:bad_date, {_date, [?\s | tz]}} <-
           {:bad_date, ParseDecimal.from_decimal_charlist(date)},
         {:bad_timezone, {_tz, [?\n | next]}} <-
           {:bad_timezone, ParseDecimal.from_decimal_charlist(tz)} do
      next
    else
      {:missing_email, _} -> cover :missing_email
      {:bad_email, _} -> cover :bad_email
      {:missing_space_before_date, _} -> cover :missing_space_before_date
      {:bad_date, _} -> cover :bad_date
      {:bad_timezone, _} -> cover :bad_time_zone
    end
  end

  defp normalize(name, true = _mac?) when is_list(name) do
    name
    |> RawParseUtils.decode()
    |> String.downcase()
    |> :unicode.characters_to_nfc_binary()
  end

  defp normalize(name, _) when is_list(name), do: Enum.map(name, &to_lower/1)

  defp to_lower(b) when b >= ?A and b <= ?Z, do: cover(b + 32)
  defp to_lower(b), do: cover(b)
end
