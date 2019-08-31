defmodule Xgit.Util.TrailingHashDevice do
  @moduledoc ~S"""
  Creates an `iodevice` process that supports git file formats with a trailing
  SHA-1 hash.

  When reading, the trailing 20 bytes are interpreted as a SHA-1 hash of the
  remaining file contents and can be verified using the `valid_hash?/1` function.

  This is an admittedly minimal implementation; just enough is implemented to
  allow Xgit's index file parser to do its work.
  """
  use GenServer

  import Xgit.Util.ForceCoverage

  require Logger

  @doc ~S"""
  Creates an IO device that reads a file with trailing hash.

  Unlike `File.open/2` and `File.open/3`, no options or function are
  accepted.

  This device can be passed to `IO.binread/2`.

  ## Return Value

  `{:ok, pid}` where `pid` points to an IO device process.

  `{:ok, reason}` if the file could not be opened. See `File.open/2` for
  possible values for `reason`.
  """
  @spec open_file(path :: Path.t()) :: {:ok, pid} | {:error, File.posix()}
  def open_file(path) when is_binary(path),
    do: GenServer.start_link(__MODULE__, {:file, path})

  @doc ~S"""
  Creates an IO device that writes to a file with trailing hash.

  Unlike `File.open/2` and `File.open/3`, no options or function are
  accepted.

  This device can be passed to `IO.binwrite/2`.

  ## Options

  `:max_file_size` (non-negative integer) may be passed, which will cause a
  failure after the _n_th byte is written. This is intended for internal
  testing purposes.

  ## Return Value

  `{:ok, pid}` where `pid` points to an IO device process.

  `{:ok, reason}` if the file could not be opened. See `File.open/2` for
  possible values for `reason`.
  """
  @spec open_file_for_write(path :: Path.t(), opts :: Keyword.t()) ::
          {:ok, pid} | {:error, File.posix()}
  def open_file_for_write(path, opts \\ []) when is_binary(path) and is_list(opts),
    do: GenServer.start_link(__MODULE__, {:file_write, path, opts})

  @doc ~S"""
  Creates an IO device that reads a string with trailing hash.

  This is intended mostly for internal testing purposes.

  Unlike `StringIO.open/2` and `StringIO.open/3`, no options or function are
  accepted.

  This device can be passed to `IO.binread/2`.

  ## Return Value

  `{:ok, pid}` where `pid` points to an IO device process.
  """
  @spec open_string(s :: binary) :: {:ok, pid}
  def open_string(s) when is_binary(s) and byte_size(s) >= 20,
    do: GenServer.start_link(__MODULE__, {:string, s})

  @doc ~S"""
  Returns `true` if this is process is an `TrailingHashDevice` instance.

  Note the difference between this function and `valid_hash?/1`.
  """
  @spec valid?(v :: any) :: boolean
  def valid?(v) when is_pid(v),
    do: GenServer.call(v, :valid_trailing_hash_read_device?) == :valid_trailing_hash_read_device

  def valid?(_), do: cover(false)

  @doc ~S"""
  Returns `true` if the hash at the end of the file matches the hash
  generated while reading the file.

  Should only be called once and only once when the entire file (sans SHA-1 hash)
  has been read.

  ## Return Values

  `true` or `false` if the SHA-1 hash was found and was valid (or not).

  `:too_soon` if called before the SHA-1 hash is expected.

  `:already_called` if called a second (or successive) time.

  `:opened_for_write` if called on a device that was opened for write.
  """
  @spec valid_hash?(io_device :: pid) :: boolean
  def valid_hash?(io_device) when is_pid(io_device),
    do: GenServer.call(io_device, :valid_hash?)

  @impl true
  def init({:file, path}) do
    with {:ok, %{size: size}} <- File.stat(path, time: :posix),
         {:ok, pid} when is_pid(pid) <- File.open(path) do
      cover {:ok,
             %{
               iodevice: pid,
               mode: :read,
               remaining_bytes: size - 20,
               crypto: :crypto.hash_init(:sha)
             }}
    else
      {:error, reason} -> cover {:stop, reason}
    end
  end

  def init({:file_write, path, opts}) do
    case File.open(path, [:write]) do
      {:ok, pid} when is_pid(pid) ->
        cover {:ok,
               %{
                 iodevice: pid,
                 mode: :write,
                 remaining_bytes: Keyword.get(opts, :max_file_size, :unlimited),
                 crypto: :crypto.hash_init(:sha)
               }}

      {:error, reason} ->
        cover {:stop, reason}
    end
  end

  def init({:string, s}) do
    {:ok, pid} = StringIO.open(s)

    cover {:ok,
           %{
             iodevice: pid,
             mode: :read,
             remaining_bytes: byte_size(s) - 20,
             crypto: :crypto.hash_init(:sha)
           }}
  end

  @impl true
  def handle_info({:io_request, from, reply_as, req}, state) do
    state = io_request(from, reply_as, req, state)
    cover {:noreply, state}
  end

  def handle_info({:file_request, from, reply_as, req}, state) do
    state = file_request(from, reply_as, req, state)
    cover {:noreply, state}
  end

  def handle_info(message, state) do
    Logger.warn("TrailingHashDevice received unexpected message #{inspect(message)}")
    cover {:noreply, state}
  end

  @impl true
  def handle_call(:valid_trailing_hash_read_device?, _from_, state),
    do: {:reply, :valid_trailing_hash_read_device, state}

  def handle_call(:valid_hash?, _from, %{mode: :write} = state),
    do: {:reply, :opened_for_write, state}

  def handle_call(:valid_hash?, _from, %{crypto: :done} = state),
    do: {:reply, :already_called, state}

  def handle_call(
        :valid_hash?,
        _from,
        %{iodevice: iodevice, mode: :read, remaining_bytes: remaining_bytes, crypto: crypto} =
          state
      )
      when remaining_bytes <= 0 do
    actual_hash = :crypto.hash_final(crypto)
    hash_from_file = IO.binread(iodevice, 20)

    {:reply, actual_hash == hash_from_file, %{state | crypto: :done}}
  end

  def handle_call(:valid_hash?, _from, state), do: {:reply, :too_soon, state}

  def handle_call(request, _from, state) do
    Logger.warn("TrailingHashDevice received unexpected call #{inspect(request)}")
    {:reply, :unknown_message, state}
  end

  defp io_request(from, reply_as, req, state) do
    {reply, state} = io_request(req, state)
    send(from, {:io_reply, reply_as, reply})
    state
  end

  defp io_request(
         {:get_chars, :"", count},
         %{mode: :read, remaining_bytes: remaining_bytes} = state
       )
       when remaining_bytes <= 0 and is_integer(count) and count >= 0 do
    cover {:eof, state}
  end

  defp io_request({:get_chars, :"", 0}, %{mode: :read} = state), do: cover({"", state})

  defp io_request(
         {:get_chars, :"", count},
         %{iodevice: iodevice, mode: :read, remaining_bytes: remaining_bytes, crypto: crypto} =
           state
       )
       when is_integer(count) and count > 0 do
    data = IO.binread(iodevice, min(remaining_bytes, count))

    if is_binary(data) do
      crypto = :crypto.hash_update(crypto, data)
      cover {data, %{state | remaining_bytes: remaining_bytes - byte_size(data), crypto: crypto}}
    else
      # coveralls-ignore-start
      # This will only occur if an I/O error occurs *mid*-file.
      # Difficult to simulate and fairly simple code, so not generating coverage for this line.
      cover {data, state}
      # coveralls-ignore-end
    end
  end

  defp io_request(
         {:put_chars, _encoding, data},
         %{
           iodevice: iodevice,
           mode: :write,
           remaining_bytes: remaining_bytes,
           crypto: crypto
         } = state
       )
       when is_integer(remaining_bytes) do
    if byte_size(data) <= remaining_bytes do
      crypto = :crypto.hash_update(crypto, data)
      IO.binwrite(iodevice, data)

      cover {:ok, %{state | remaining_bytes: remaining_bytes - byte_size(data), crypto: crypto}}
    else
      cover {{:error, :eio}, %{state | remaining_bytes: 0}}
    end
  end

  defp io_request(
         {:put_chars, _encoding, data},
         %{
           iodevice: iodevice,
           mode: :write,
           remaining_bytes: :unlimited,
           crypto: crypto
         } = state
       ) do
    crypto = :crypto.hash_update(crypto, data)
    IO.binwrite(iodevice, data)

    cover {:ok, %{state | crypto: crypto}}
  end

  defp io_request(request, state) do
    Logger.warn("TrailingHashDevice received unexpected iorequest #{inspect(request)}")
    cover {{:error, :request}, state}
  end

  defp file_request(from, reply_as, req, state) do
    {reply, state} = file_request(req, state)
    send(from, {:file_reply, reply_as, reply})
    state
  end

  defp file_request(
         :close,
         %{iodevice: iodevice, mode: :write, crypto: crypto} = state
       ) do
    hash = :crypto.hash_final(crypto)
    IO.binwrite(iodevice, hash)

    cover {File.close(iodevice), %{state | iodevice: nil}}
  end

  defp file_request(:close, %{iodevice: iodevice} = state),
    do: cover({File.close(iodevice), %{state | iodevice: nil}})

  defp file_request(request, state) do
    Logger.warn("TrailingHashDevice received unexpected file_request #{inspect(request)}")
    cover {{:error, :request}, state}
  end
end
