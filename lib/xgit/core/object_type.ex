defmodule Xgit.Core.ObjectType do
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

  @object_types [:blob, :tree, :commit, :tag]

  @typedoc ~S"""
  One of the four known git object types, expressed as an atom.
  """
  @type t :: :blob | :tree | :commit | :tag

  @doc ~S"""
  This guard requires the value to be one of the four known git object types.
  """
  defguard is_object_type(t) when t in @object_types

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias Xgit.Core.ObjectType
      import Xgit.Core.ObjectType, only: [is_object_type: 1]
    end
  end
end
