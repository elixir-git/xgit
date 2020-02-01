defmodule Xgit.Util.UnzipStream do
  @moduledoc false

  # Internal utility that transforms a stream from a compressed
  # ZIP stream to uncompressed data.

  import Xgit.Util.ForceCoverage

  @doc ~S"""
  Transforms a stream from a compressed ZIP stream to uncompressed data.
  """
  @spec unzip(compressed_stream :: Enum.t()) :: Enum.t()
  def unzip(compressed_stream),
    do: Stream.transform(compressed_stream, &start/0, &process_data/2, &finish/1)

  defp start do
    z = :zlib.open()
    :ok = :zlib.inflateInit(z)
    z
  end

  defp process_data(compressed_data, z) do
    cover {compressed_data
           |> process_all_data(z, [])
           |> Enum.reverse()
           |> Enum.concat(), z}
  end

  defp process_all_data(compressed_data, z, uncompressed_data_acc) do
    {status, iodata} = :zlib.safeInflate(z, compressed_data)

    case status do
      :continue ->
        process_all_data([], z, [to_byte_list(iodata) | uncompressed_data_acc])

      :finished ->
        cover [to_byte_list(iodata) | uncompressed_data_acc]
    end
  end

  defp to_byte_list([]), do: cover([])
  defp to_byte_list([b]) when is_binary(b), do: :binary.bin_to_list(b)

  defp finish(z) do
    :ok = :zlib.inflateEnd(z)
    :ok = :zlib.close(z)
    cover nil
  end
end
