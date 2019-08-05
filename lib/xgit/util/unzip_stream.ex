defmodule Xgit.Util.UnzipStream do
  @moduledoc ~S"""
  Implements a stream transformation to unzip a file.
  """

  def unzip(compressed_stream),
    do: Stream.transform(compressed_stream, &start/0, &process_data/2, &finish/1)

  defp start do
    z = :zlib.open()
    :ok = :zlib.inflateInit(z)
    z
  end

  defp process_data(compressed_data, z) do
    {compressed_data
     |> process_all_data(z, [])
     |> Enum.reverse()
     |> Enum.concat(), z}
  end

  defp process_all_data(compressed_data, z, uncompressed_data_acc) do
    {status, iodata} = :zlib.safeInflate(z, compressed_data)

    case status do
      :continue -> process_all_data([], z, [to_byte_list(iodata) | uncompressed_data_acc])
      # TO DO: The `:continue` case is unreachable in code coverage by any case
      # that I've been able to construct. Would love advice on how to reach this.
      # https://github.com/elixir-git/xgit/issues/50

      :finished -> [to_byte_list(iodata) | uncompressed_data_acc]
    end
  end

  defp to_byte_list([]), do: []
  defp to_byte_list([b]) when is_binary(b), do: :binary.bin_to_list(b)

  defp finish(z) do
    :ok = :zlib.inflateEnd(z)
    :ok = :zlib.close(z)
    nil
  end
end
