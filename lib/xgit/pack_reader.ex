defmodule Xgit.PackReader do
  @moduledoc ~S"""
  Given a combination of `.pack` and `.idx` files, a pack reader
  can access the objects within it.
  """

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  This struct describes a single object pack, including information from its
  pack and index files.

  ## Struct Members

  * `:idx_version`: the index version (either 1 or 2)
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
          fanout: tuple,
          offset_sha: binary | nil,
          sha1: binary | nil,
          crc: binary | nil,
          offset: binary | nil,
          offset_64bit: binary | nil,
          packfile_checksum: binary,
          idxfile_checksum: binary
        }

  @enforce_keys [:pack_path, :idx_version, :fanout, :packfile_checksum, :idxfile_checksum]
  defstruct [
    :pack_path,
    :idx_version,
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

  `{:rror, :invalid_index}` if the index file can not be parsed.
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
    with {:ok, iodevice} <- File.open(idx_path, [:read, :binary]) do
      res = read_index_file(pack_path, iodevice)
      File.close(iodevice)
      res
    else
      {:error, err} -> cover {:error, err}
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

  def read_index_file_v2(pack_path, idx_iodevice) do
    with "\x00\x00\x00\x02" <- IO.binread(idx_iodevice, 4),
         fanout when is_binary(fanout) <- IO.binread(idx_iodevice, 1024) do
      {:ok,
       %__MODULE__{
         pack_path: pack_path,
         idx_version: 2,
         fanout: fanout,
         sha1: "TO DO: sha1",
         crc: "TO DO: crc",
         offset: "TO DO: offset",
         offset_64bit: "TO DO: offset_64bit",
         packfile_checksum: "TO DO: packfile_checksum",
         idxfile_checksum: "TO DO: idxfile_checksum"
       }}
    else
      _ -> {:error, :invalid_index}
    end
  end

  # def has_object?(_reader, _object_id) do
  #   raise "unimplemented"
  # end

  # def get_object(_reader, _object_id) do
  #   raise "unimplemented"
  # end

  # TO DO: Some kind of iterator for pack object IDs.
end
