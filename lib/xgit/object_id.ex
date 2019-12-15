defmodule Xgit.ObjectId do
  @moduledoc ~S"""
  An object ID is a string that identifies an object within a repository.

  This string must match the format for a SHA-1 hash (i.e. 40 characters
  of lowercase hex).
  """
  use Xgit.ObjectType

  import Xgit.Util.ForceCoverage

  alias Xgit.ContentSource

  @typedoc "A string containing 40 bytes of lowercase hex digits."
  @type t :: String.t()

  @doc ~S"""
  Get the special all-null object ID, often used to stand-in for no object.
  """
  @spec zero :: t
  def zero, do: cover("0000000000000000000000000000000000000000")

  @doc ~S"""
  Returns `true` if the value is a valid object ID.

  (In other words, is it a string containing 40 characters of lowercase hex?)
  """
  @spec valid?(id :: term) :: boolean
  def valid?(id)

  def valid?(s) when is_binary(s), do: String.length(s) == 40 && String.match?(s, ~r/^[0-9a-f]+$/)
  def valid?(_), do: cover(false)

  @doc ~S"""
  Read an object ID from raw binary or bytelist.

  ## Parameters

  `raw_object_id` should be either a binary or list containing a raw object ID (not
  hex-encoded). It should be exactly 20 bytes.

  ## Return Value

  The object ID rendered as lowercase hex. (See `Xgit.ObjectId`.)
  """
  @spec from_binary_iodata(b :: iodata) :: t
  def from_binary_iodata(b) when is_list(b) do
    b
    |> IO.iodata_to_binary()
    |> from_binary_iodata()
  end

  def from_binary_iodata(b) when is_binary(b) and byte_size(b) == 20,
    do: Base.encode16(b, case: :lower)

  @doc ~S"""
  Read an object ID from a hex string (charlist).

  ## Return Value

  If a valid ID is found, returns `{id, next}` where `id` is the matched ID
  as a string and `next` is the remainder of the charlist after the matched ID.

  If no such ID is found, returns `false`.
  """
  @spec from_hex_charlist(b :: charlist) :: {t, charlist} | false
  def from_hex_charlist(b) when is_list(b) do
    {maybe_id, remainder} = Enum.split(b, 40)

    with maybe_id_string <- to_string(maybe_id),
         true <- valid?(maybe_id_string) do
      cover {maybe_id_string, remainder}
    else
      _ -> cover false
    end
  end

  @doc ~S"""
  Convert an object ID to raw binary representation.

  ## Return Value

  A 20-byte binary encoding the object ID.
  """
  @spec to_binary_iodata(id :: t) :: binary
  def to_binary_iodata(id), do: Base.decode16!(id, case: :lower)

  @doc ~S"""
  Assign an object ID for a given data blob.

  No validation is performed on the content.

  ## Parameters

  * `data` describes how to read the data. (See `Xgit.ContentSource`.)
  * `type` is the intended git object type for this data. (See `Xgit.ObjectType`.)

  ## Return Value

  The object ID. (See `Xgit.ObjectId`.)
  """
  @spec calculate_id(data :: ContentSource.t(), type :: ObjectType.t()) :: t()
  def calculate_id(data, type) when not is_nil(data) and is_object_type(type) do
    size = ContentSource.length(data)

    # Erlang/Elixir :sha == SHA-1
    :sha
    |> :crypto.hash_init()
    |> :crypto.hash_update('#{type}')
    |> :crypto.hash_update(' ')
    |> :crypto.hash_update('#{size}')
    |> :crypto.hash_update([0])
    |> hash_update(ContentSource.stream(data))
    |> :crypto.hash_final()
    |> from_binary_iodata()
  end

  defp hash_update(crypto_state, data) when is_list(data),
    do: :crypto.hash_update(crypto_state, data)

  defp hash_update(crypto_state, data) do
    Enum.reduce(data, crypto_state, fn item, crypto_state ->
      :crypto.hash_update(crypto_state, item)
    end)
  end
end
