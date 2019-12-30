defmodule Xgit.ObjectType do
  @moduledoc ~S"""
  Describes the known git object types.

  There are four distinct object types that can be stored in a git repository.
  Xgit communicates internally about these object types using the following
  atoms:

  * `:blob`
  * `:tree`
  * `:commit`
  * `:tag`

  This module is intended to be `use`d. Doing so will create an `alias` to the module
  so as to make `ObjectType.t` available for typespecs and will `import` the
  `is_object_type/1` guard.
  """

  import Xgit.Util.ForceCoverage

  @object_types [:blob, :tree, :commit, :tag]

  @typedoc ~S"""
  One of the four known git object types, expressed as an atom.
  """
  @type t :: :blob | :tree | :commit | :tag

  @doc ~S"""
  Return `true` if the value is one of the four known git object types.
  """
  @spec valid?(t :: term) :: boolean
  def valid?(t), do: t in @object_types

  @doc ~S"""
  This guard requires the value to be one of the four known git object types.
  """
  defguard is_object_type(t) when t in @object_types

  @doc ~S"""
  Parses a byte list and converts it to an object-type atom.

  Returns `:error` if the byte list doesn't match any of the known-valid object types.
  """
  @spec from_bytelist(value :: [byte]) :: t | :error
  def from_bytelist(value)

  def from_bytelist('blob'), do: cover(:blob)
  def from_bytelist('tree'), do: cover(:tree)
  def from_bytelist('commit'), do: cover(:commit)
  def from_bytelist('tag'), do: cover(:tag)
  def from_bytelist(value) when is_list(value), do: cover(:error)

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias Xgit.ObjectType
      import Xgit.ObjectType, only: [is_object_type: 1]
    end
  end
end
