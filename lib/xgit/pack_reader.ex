defmodule Xgit.PackReader do
  @moduledoc ~S"""
  Given a combination of `.pack` and `.idx` files, a pack reader
  can access the objects within it.

  A `PackReader` implements the `Enumerable` protocol. An iteration
  of a `PackReader` struct will produce a series of `Xgit.PackReader.Entry`
  structs describing the name, position, and (for V2 packs only)
  the CRC sum for each object as described in the pack index.
  """

  use Bitwise, only_operators: true

  alias Xgit.FileContentSource
  alias Xgit.Object
  alias Xgit.ObjectId
  alias Xgit.Util.NB

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  This struct describes a single object pack, including information from its
  pack and index files.

  ## Struct Members

  * `:pack_path`: path to the pack file
  * `:idx_version`: the index version (either 1 or 2)
  * `:count`: number of objects in this pack
  * `:fanout`: fanout table (256-element tuple); indexes into offset and/or sha tables
  * `:offset_sha`: (binary) offset + SHAs table (version 1 only)
  * `:sha1`: (binary) SHA listings (version 2 only)
  * `:crc`: (binary) CRC checksums (version 2 only)
  * `:offset`: (binary) pack file offsets (for version 2 only)
  * `:offset_64bit`: (binary) large pack file offsets (version 2 only)
  * `:packfile_checksum`: (binary) SHA-1 hash of pack file
  * `:idxfile_checksum`: (binary) SHA-1 hash of index file
  """
  @type t :: %__MODULE__{
          pack_path: Path.t(),
          idx_version: 1..2,
          count: non_neg_integer,
          fanout: tuple,
          offset_sha: binary | nil,
          sha1: binary | nil,
          crc: binary | nil,
          offset: binary | nil,
          offset_64bit: binary | nil,
          packfile_checksum: binary,
          idxfile_checksum: binary
        }

  @enforce_keys [:pack_path, :idx_version, :count, :fanout, :packfile_checksum, :idxfile_checksum]
  defstruct [
    :pack_path,
    :idx_version,
    :count,
    :fanout,
    :offset_sha,
    :sha1,
    :crc,
    :offset,
    :offset_64bit,
    :packfile_checksum,
    :idxfile_checksum
  ]

  @typedoc ~S"""
  Error responses for `open/2`.
  """
  @type open_reason :: File.posix() | :invalid_index

  @doc ~S"""
  Open a pack reader for a related `.pack` and `.idx` file pair.

  ## Return Values

  `{:ok, pack_reader}` if successful.

  `{:error, posix}` if unable to physically access either file.

  `{:error, :invalid_index}` if the index file can not be parsed.
  """
  @spec open(pack_path :: Path.t(), idx_path :: Path.t()) :: {:ok, t} | {:error, open_reason}
  def open(pack_path, idx_path) when is_binary(pack_path) and is_binary(idx_path) do
    case read_index(pack_path, idx_path) do
      {:ok, %__MODULE__{} = reader} ->
        # TO DO: Also verify pack file.
        cover {:ok, reader}

      {:error, err} ->
        cover {:error, err}
    end
  end

  defp read_index(pack_path, idx_path) do
    case File.open(idx_path, [:read, :binary]) do
      {:ok, iodevice} ->
        res = read_index_file(pack_path, iodevice)
        File.close(iodevice)
        cover res

      {:error, err} ->
        cover {:error, err}
    end
  end

  defp read_index_file(pack_path, idx_iodevice) do
    case IO.binread(idx_iodevice, 4) do
      "\xFFtOc" -> read_index_file_v2(pack_path, idx_iodevice)
      fanout0 -> read_index_file_v1(pack_path, idx_iodevice, fanout0)
    end
  end

  defp read_index_file_v1(pack_path, idx_iodevice, fanout0) do
    fanout0 =
      fanout0
      |> :erlang.binary_to_list()
      |> NB.decode_uint32()
      |> elem(0)

    with {fanout, count} when is_tuple(fanout) <- read_fanout_table(idx_iodevice, fanout0),
         {:ok, offset_sha} <- read_blob(idx_iodevice, count * 24),
         {:ok, packfile_checksum} <- read_blob(idx_iodevice, 20),
         {:ok, idxfile_checksum} <- read_blob(idx_iodevice, 20),
         :error <- read_blob(idx_iodevice, 1) do
      cover {:ok,
             %__MODULE__{
               pack_path: pack_path,
               idx_version: 1,
               count: count,
               fanout: fanout,
               offset_sha: offset_sha,
               packfile_checksum: packfile_checksum,
               idxfile_checksum: idxfile_checksum
             }}
    else
      _ -> cover {:error, :invalid_index}
    end
  end

  defp read_fanout_table(idx_iodevice, fanout0) do
    with entries <-
           Enum.concat([fanout0], Enum.map(1..255, fn _ -> read_fanout_entry(idx_iodevice) end)),
         size when is_integer(size) <- check_fanout_table(entries) do
      cover {List.to_tuple(entries), size}
    end
  end

  defp read_index_file_v2(pack_path, idx_iodevice) do
    with "\x00\x00\x00\x02" <- IO.binread(idx_iodevice, 4),
         {fanout, count} when is_tuple(fanout) <- read_fanout_table(idx_iodevice),
         {:ok, sha1} <- read_blob(idx_iodevice, count * 20),
         {:ok, crc} <- read_blob(idx_iodevice, count * 4),
         {:ok, offset} <- read_blob(idx_iodevice, count * 4),
         offset_64bit <- "TO DO: read offset_64bit",
         {:ok, packfile_checksum} <- read_blob(idx_iodevice, 20),
         {:ok, idxfile_checksum} <- read_blob(idx_iodevice, 20),
         :error <- read_blob(idx_iodevice, 1) do
      cover {:ok,
             %__MODULE__{
               pack_path: pack_path,
               idx_version: 2,
               count: count,
               fanout: fanout,
               sha1: sha1,
               crc: crc,
               offset: offset,
               offset_64bit: offset_64bit,
               packfile_checksum: packfile_checksum,
               idxfile_checksum: idxfile_checksum
             }}
    else
      _ -> cover {:error, :invalid_index}
    end
  end

  defp read_fanout_table(idx_iodevice) do
    with entries <- Enum.map(0..255, fn _ -> read_fanout_entry(idx_iodevice) end),
         size when is_integer(size) <- check_fanout_table(entries) do
      cover {List.to_tuple(entries), size}
    end
  end

  defp read_fanout_entry(idx_iodevice) do
    with bin when is_binary(bin) <- IO.binread(idx_iodevice, 4),
         list <- :erlang.binary_to_list(bin),
         {size, []} <- NB.decode_uint32(list) do
      cover size
    end
  end

  defp check_fanout_table(entries) do
    Enum.reduce_while(entries, 0, &check_fanout_entry/2)
  end

  defp check_fanout_entry(current, previous) when is_integer(current) and current >= previous do
    cover {:cont, current}
  end

  defp check_fanout_entry(_current, _previous) do
    cover {:halt, :error}
  end

  defp read_blob(idx_iodevice, size) do
    with bin when is_binary(bin) <- IO.binread(idx_iodevice, size),
         ^size <- byte_size(bin) do
      cover {:ok, bin}
    else
      _ -> cover :error
    end
  end

  @doc ~S"""
  Return `true` if the object in question is present in this pack.
  """
  @spec has_object?(reader :: t, object_id :: ObjectId.t()) :: boolean
  def has_object?(reader, object_id) do
    case index_for_object_id(reader, object_id) do
      nil -> cover false
      _ -> cover true
    end
  end

  defp index_for_object_id(%__MODULE__{fanout: fanout} = reader, object_id)
       when is_binary(object_id) do
    binary_id = ObjectId.to_binary_iodata(object_id)
    fanout_index = :binary.at(binary_id, 0)

    # Potential optimization: Binary search between starting_index and next fanout index entry.

    starting_index =
      case fanout_index do
        0 -> cover 0
        x -> elem(fanout, x - 1)
      end

    index_for_object_id(reader, binary_id, starting_index)
  end

  defp index_for_object_id(reader, binary_id, index)

  defp index_for_object_id(%__MODULE__{count: count}, _binary_id, count), do: cover(nil)

  defp index_for_object_id(
         %__MODULE__{idx_version: 1, offset_sha: offset_sha} = reader,
         binary_id,
         index
       ) do
    id_at_offset = :binary.part(offset_sha, index * 24 + 4, 20)

    cond do
      id_at_offset == binary_id -> cover(index)
      id_at_offset > binary_id -> cover(nil)
      true -> index_for_object_id(reader, binary_id, index + 1)
    end
  end

  defp index_for_object_id(
         %__MODULE__{idx_version: 2, sha1: sha1} = reader,
         binary_id,
         index
       ) do
    id_at_offset = :binary.part(sha1, index * 20, 20)

    cond do
      id_at_offset == binary_id -> cover(index)
      id_at_offset > binary_id -> cover(nil)
      true -> index_for_object_id(reader, binary_id, index + 1)
    end
  end

  @typedoc ~S"""
  Error codes that can be returned by `get_object/2`.
  """
  @type get_object_reason :: :not_found | :invalid_object

  @doc ~S"""
  Retrieves an object from the pack.

  ## Return Value

  `{:ok, object}` if the object exists in the pack.

  `{:error, :not_found}` if the object does not exist in the pack.

  `{:error, :invalid_object}` if object was found, but invalid.
  """
  @spec get_object(pack_reader :: t(), object_id :: ObjectId.t()) ::
          {:ok, object :: Object.t()} | {:error, reason :: get_object_reason()}
  def get_object(%__MODULE__{} = reader, object_id) when is_binary(object_id) do
    index = index_for_object_id(reader, object_id)

    if is_integer(index) do
      pack_entry = pack_entry_at_index(reader, index)
      object_from_pack(reader, pack_entry)
    else
      cover {:error, :not_found}
    end
  end

  defmodule Entry do
    @moduledoc ~S"""
    Represents a single entry from a pack index.

    ## Struct Members

    * `:name`: (`Xgit.ObjectID.t`) SHA1 name of the object
    * `:offset`: (integer) offset of the packed object in the pack file
    * `:crc`: (optional, binary) CRC checksum of the packed object
    """
    @type t :: %__MODULE__{
            name: Xgit.ObjectId.t(),
            offset: non_neg_integer,
            crc: binary | nil
          }

    @enforce_keys [:name, :offset]
    defstruct [:name, :offset, :crc]
  end

  @doc ~S"""
  Return a single entry from the pack index.
  """
  @spec pack_entry_at_index(reader :: t, index :: non_neg_integer) :: __MODULE__.Entry.t()
  def pack_entry_at_index(%__MODULE__{idx_version: 1, offset_sha: offset_sha} = _reader, index) do
    name =
      offset_sha
      |> :binary.part(index * 24 + 4, 20)
      |> ObjectId.from_binary_iodata()

    offset =
      offset_sha
      |> :binary.part(index * 24, 4)
      |> :binary.bin_to_list()
      |> NB.decode_uint32()
      |> elem(0)

    %__MODULE__.Entry{name: name, offset: offset}
  end

  def pack_entry_at_index(
        %__MODULE__{idx_version: 2, sha1: sha1, offset: offset, crc: crc} = _reader,
        index
      ) do
    name =
      sha1
      |> :binary.part(index * 20, 20)
      |> ObjectId.from_binary_iodata()

    offset =
      offset
      |> :binary.part(index * 4, 4)
      |> :binary.bin_to_list()
      |> NB.decode_uint32()
      |> elem(0)

    # TO DO: Add support for 64-bit offsets when reading V2 pack files.
    # https://github.com/elixir-git/xgit/issues/320

    # coveralls-ignore-start
    if offset > 0x80000000 do
      raise "64-bit offsets not yet supported"
    end

    # coveralls-ignore-stop

    crc =
      crc
      |> :binary.part(index * 4, 4)
      |> :binary.bin_to_list()
      |> NB.decode_uint32()
      |> elem(0)

    %__MODULE__.Entry{name: name, offset: offset, crc: crc}
  end

  defp object_from_pack(
         %__MODULE__{pack_path: pack_path} = reader,
         %__MODULE__.Entry{name: object_id, offset: offset} = _pack_entry
       ) do
    case File.open(pack_path, [:read, :binary]) do
      {:ok, pack_iodevice} ->
        res = read_object_from_pack(reader, pack_iodevice, offset, object_id)
        File.close(pack_iodevice)
        cover res

      {:error, err} ->
        cover {:error, err}
    end
  end

  defp read_object_from_pack(reader, pack_iodevice, offset, object_id) do
    with <<?P, ?A, ?C, ?K, 0, 0, 0, 2>> <- IO.binread(pack_iodevice, 8),
         {:ok, ^offset} <- :file.position(pack_iodevice, offset),
         {type, size} <- object_type_and_size(pack_iodevice) do
      unpack_object(reader, pack_iodevice, object_id, type, size)
    else
      _ -> cover {:error, :invalid_object}
    end
  end

  defp object_type_and_size(pack_iodevice) do
    with <<more?::1, type_code::3, size::4>> <- IO.binread(pack_iodevice, 1),
         size when is_integer(size) <- read_more_size(pack_iodevice, more?, size, 4) do
      cover {type_code_to_type(type_code), size}
    else
      _ -> cover :error
    end
  end

  defp read_more_size(_pack_iodevice, 0, size, _), do: cover(size)

  defp read_more_size(pack_iodevice, 1, size, bitshift) do
    with <<more?::1, more_size::7>> <- IO.binread(pack_iodevice, 1) do
      read_more_size(pack_iodevice, more?, size + (more_size <<< bitshift), bitshift + 7)
    else
      _ -> :error
    end
  end

  defp type_code_to_type(1), do: cover(:commit)
  defp type_code_to_type(2), do: cover(:tree)
  defp type_code_to_type(3), do: cover(:blob)
  defp type_code_to_type(4), do: cover(:tag)
  defp type_code_to_type(6), do: cover(:ofs_delta)
  defp type_code_to_type(7), do: cover(:ref_delta)
  defp type_code_to_type(_), do: cover(:error)

  defp unpack_object(_reader, _pack_iodevice, _object_id, :ofs_delta, _size) do
    raise "unimplemented"
  end

  defp unpack_object(_reader, _pack_iodevice, _object_id, :ref_delta, _size) do
    raise "unimplemented"
  end

  defp unpack_object(_reader, _pack_iodevice, _object_id, :error, _size) do
    cover {:error, :invalid_object}
  end

  @read_chunk_size 64

  defp unpack_object(_reader, pack_iodevice, object_id, type, size) do
    Temp.track!()
    z = :zlib.open()

    with :ok <- :zlib.inflateInit(z),
         {:ok, path} <- Temp.path(),
         {:ok, unpacked_iodevice} <- File.open(path, [:write, :binary]),
         :ok <- inflate_object(z, pack_iodevice, unpacked_iodevice, {:continue, ""}),
         :ok <- File.close(unpacked_iodevice) do
      cover {:ok,
             %Object{
               content: FileContentSource.new(path),
               id: object_id,
               size: size,
               type: type
             }}
    else
      _ -> cover {:error, :invalid_object}
    end
  end

  defp inflate_object(_z, _pack_iodevice, _unpacked_iodevice, {:finished, []}) do
    cover :ok
  end

  defp inflate_object(z, pack_iodevice, unpacked_iodevice, {_verb, data}) do
    with :ok <- IO.binwrite(unpacked_iodevice, data),
         next_data when is_binary(next_data) <- IO.binread(pack_iodevice, @read_chunk_size) do
      inflate_object(z, pack_iodevice, unpacked_iodevice, :zlib.safeInflate(z, next_data))
    else
      :eof -> cover :ok
      _ -> cover :error
    end
  end

  defimpl Enumerable do
    alias Xgit.ObjectId
    alias Xgit.PackReader

    @impl true
    def count(%PackReader{count: count}), do: cover({:ok, count})

    @impl true
    def member?(_, _), do: {:error, PackReader}

    @impl true
    def slice(_), do: {:error, PackReader}

    @impl true
    def reduce(%PackReader{idx_version: 1} = reader, acc, fun) do
      reduce_v1(reader, 0, acc, fun)
    end

    def reduce(%PackReader{idx_version: 2} = reader, acc, fun) do
      reduce_v2(reader, 0, acc, fun)
    end

    defp reduce_v1(reader, index, acc, fun)

    defp reduce_v1(_reader, _index, {:halt, acc}, _fun), do: cover({:halted, acc})

    # TO DO: Restore this case if we find that we actually use suspended enumerations.
    # For now, I don't see a use case for it.
    # defp reduce_v1(_reader, _index, {:suspend, acc}, _fun) do
    #   {:suspended, acc, &reduce_v1(reader, index, &1, fun)}
    # end

    defp reduce_v1(%PackReader{count: index}, index, {:cont, acc}, _fun) do
      cover {:done, acc}
    end

    defp reduce_v1(reader, index, {:cont, acc}, fun) do
      entry = PackReader.pack_entry_at_index(reader, index)
      reduce_v1(reader, index + 1, fun.(entry, acc), fun)
    end

    defp reduce_v2(reader, index, acc, fun)

    defp reduce_v2(_reader, _index, {:halt, acc}, _fun), do: cover({:halted, acc})

    # TO DO: Restore this case if we find that we actually use suspended enumerations.
    # For now, I don't see a use case for it.
    # defp reduce_v2(_reader, _index, {:suspend, acc}, _fun) do
    #   {:suspended, acc, &reduce_v2(reader, index, &1, fun)}
    # end

    defp reduce_v2(%PackReader{count: index}, index, {:cont, acc}, _fun) do
      cover {:done, acc}
    end

    defp reduce_v2(reader, index, {:cont, acc}, fun) do
      entry = PackReader.pack_entry_at_index(reader, index)
      reduce_v2(reader, index + 1, fun.(entry, acc), fun)
    end
  end
end
