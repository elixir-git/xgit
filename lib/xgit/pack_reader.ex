defmodule Xgit.PackReader do
  @moduledoc ~S"""
  Given a combination of `.pack` and `.idx` files, a pack reader
  can access the objects within it.

  A `PackReader` implements the `Enumerable` protocol. An iteration
  of a `PackReader` struct will produce a series of `Xgit.PackReader.Entry`
  structs describing the name, position, and (for V2 packs only)
  the CRC sum for each object as described in the pack index.
  """

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
    with {:exists?, true} <- {:exists?, File.exists?(idx_path)},
         {:ok, %__MODULE__{} = reader} <- read_index(pack_path, idx_path) do
      # TO DO: Also verify pack file.
      cover {:ok, reader}
    else
      {:exists?, _} -> cover {:error, :enoent}
      {:error, err} -> cover {:error, err}
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

  defp read_index_file_v1(_pack_path, _idx_iodevice, _fanout0) do
    raise "unimplemented"
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
      {:ok,
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
      {List.to_tuple(entries), size}
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

  # def has_object?(_reader, _object_id) do
  #   raise "unimplemented"
  # end

  # def get_object(_reader, _object_id) do
  #   raise "unimplemented"
  # end

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

  defimpl Enumerable do
    alias Xgit.ObjectId
    alias Xgit.PackReader
    alias Xgit.PackReader.Entry

    @impl true
    def count(%PackReader{count: count}), do: cover({:ok, count})

    @impl true
    def member?(_, _), do: cover({:error, PackReader})

    @impl true
    def slice(_), do: cover({:error, PackReader})

    @impl true
    def reduce(%PackReader{idx_version: 2} = reader, acc, fun) do
      reduce_v2(reader, 0, acc, fun)
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

    defp reduce_v2(
           %PackReader{sha1: sha1, offset: offset, crc: crc} = reader,
           index,
           {:cont, acc},
           fun
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

      entry = %Entry{name: name, offset: offset, crc: crc}

      reduce_v2(reader, index + 1, fun.(entry, acc), fun)
    end
  end
end
