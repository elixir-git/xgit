defmodule Xgit.Repository.OnDisk.PutLooseObject do
  @moduledoc false
  # Implements Xgit.Repository.OnDisk.handle_put_loose_object/2.

  alias Xgit.Core.ContentSource
  alias Xgit.Core.Object

  @spec handle_put_loose_object(state :: any, object :: Object.t()) ::
          {:ok, state :: any}
          | {:error, reason :: :cant_create_file | :object_exists, state :: any}
  def handle_put_loose_object(%{git_dir: git_dir} = state, %Object{id: id} = object) do
    object_dir = Path.join([git_dir, "objects", String.slice(id, 0, 2)])
    path = Path.join(object_dir, String.slice(id, 2, 38))

    with {:mkdir, :ok} <-
           {:mkdir, File.mkdir_p(object_dir)},
         {:file, {:ok, :ok}} <-
           {:file,
            File.open(path, [:write, :binary, :exclusive], fn file_pid ->
              deflate_and_write(file_pid, object)
            end)} do
      {:ok, state}
    else
      {:mkdir, _} ->
        {:error, :cant_create_file, state}

      {:file, {:error, :eexist}} ->
        {:error, :object_exists, state}
    end
  end

  defp deflate_and_write(file, %Object{type: type, size: size, content: content}) do
    z = :zlib.open()
    :ok = :zlib.deflateInit(z, 1)

    deflate_and_write_bytes(file, z, '#{type} #{size}')
    deflate_and_write_bytes(file, z, [0])

    if is_list(content) do
      deflate_and_write_bytes(file, z, content, :finish)
    else
      deflate_content(file, z, content)
      deflate_and_write_bytes(file, z, [], :finish)
    end

    :zlib.deflateEnd(z)
  end

  defp deflate_content(file, z, content) do
    content
    |> ContentSource.stream()
    |> Stream.each(fn chunk ->
      deflate_and_write_bytes(file, z, [chunk])
    end)
    |> Stream.run()
  end

  defp deflate_and_write_bytes(file, z, bytes, flush \\ :none),
    do: IO.binwrite(file, :zlib.deflate(z, bytes, flush))
end
