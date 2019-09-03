defmodule Xgit.Core.FileMode do
  @moduledoc ~S"""
  Describes the file type as represented on disk.
  """

  import Xgit.Util.ForceCoverage

  @typedoc ~S"""
  An integer describing the file type as represented on disk.

  Git uses a variation on the Unix file permissions flags to denote a file's
  intended type on disk. The following values are recognized:

  * `0o100644` - normal file
  * `0o100755` - executable file
  * `0o120000` - symbolic link
  * `0o040000` - tree (subdirectory)
  * `0o160000` - submodule (aka gitlink)

  This module is intended to be `use`d. Doing so will create an `alias` to the module
  so as to make `FileMode.t` available for typespecs and will `import` the
  `is_file_mode/1` guard.
  """
  @type t :: 0o100644 | 0o100755 | 0o120000 | 0o040000 | 0o160000

  @doc "Mode indicating an entry is a tree (aka directory)."
  @spec tree :: t
  def tree, do: cover(0o040000)

  @doc "Mode indicating an entry is a symbolic link."
  @spec symlink :: t
  def symlink, do: cover(0o120000)

  @doc "Mode indicating an entry is a non-executable file."
  @spec regular_file :: t
  def regular_file, do: cover(0o100644)

  @doc "Mode indicating an entry is an executable file."
  @spec executable_file :: t
  def executable_file, do: cover(0o100755)

  @doc "Mode indicating an entry is a submodule commit in another repository."
  @spec gitlink :: t
  def gitlink, do: cover(0o160000)

  @doc "Return `true` if the file mode represents a tree."
  @spec tree?(file_mode :: term) :: boolean
  def tree?(file_mode)
  def tree?(0o040000), do: cover(true)
  def tree?(_), do: cover(false)

  @doc "Return `true` if the file mode a symbolic link."
  @spec symlink?(file_mode :: term) :: boolean
  def symlink?(file_mode)
  def symlink?(0o120000), do: cover(true)
  def symlink?(_), do: cover(false)

  @doc "Return `true` if the file mode represents a regular file."
  @spec regular_file?(file_mode :: term) :: boolean
  def regular_file?(file_mode)
  def regular_file?(0o100644), do: cover(true)
  def regular_file?(_), do: cover(false)

  @doc "Return `true` if the file mode represents an executable file."
  @spec executable_file?(file_mode :: term) :: boolean
  def executable_file?(file_mode)
  def executable_file?(0o100755), do: cover(true)
  def executable_file?(_), do: cover(false)

  @doc "Return `true` if the file mode represents a submodule commit in another repository."
  @spec gitlink?(file_mode :: term) :: boolean
  def gitlink?(file_mode)
  def gitlink?(0o160000), do: cover(true)
  def gitlink?(_), do: cover(false)

  @doc ~S"""
  Return `true` if the value is one of the known file mode values.
  """
  @spec valid?(term) :: boolean
  def valid?(0o040000), do: cover(true)
  def valid?(0o120000), do: cover(true)
  def valid?(0o100644), do: cover(true)
  def valid?(0o100755), do: cover(true)
  def valid?(0o160000), do: cover(true)
  def valid?(_), do: cover(false)

  @valid_file_modes [0o100644, 0o100755, 0o120000, 0o040000, 0o160000]

  @doc ~S"""
  Return a rendered version of this file mode as an octal charlist.

  Optimized for the known file modes. Errors out for any other mode.
  """
  @spec to_octal(file_mode :: t) :: charlist
  def to_octal(file_mode)

  def to_octal(0o040000), do: cover('040000')
  def to_octal(0o120000), do: cover('120000')
  def to_octal(0o100644), do: cover('100644')
  def to_octal(0o100755), do: cover('100755')
  def to_octal(0o160000), do: cover('160000')

  @doc ~S"""
  This guard requires the value to be one of the known git file mode values.
  """
  defguard is_file_mode(t) when t in @valid_file_modes

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias Xgit.Core.FileMode
      import Xgit.Core.FileMode, only: [is_file_mode: 1]
    end
  end
end
