defmodule Xgit.Core.FileModeTest do
  use ExUnit.Case, async: true

  use Xgit.Core.FileMode

  test "tree/0" do
    assert FileMode.tree() == 0o040000
  end

  test "symlink/0" do
    assert FileMode.symlink() == 0o120000
  end

  test "regular_file/0" do
    assert FileMode.regular_file() == 0o100644
  end

  test "executable_file/0" do
    assert FileMode.executable_file() == 0o100755
  end

  test "gitlink/0" do
    assert FileMode.gitlink() == 0o160000
  end

  test "tree?/1" do
    assert FileMode.tree?(FileMode.tree())
    refute FileMode.tree?(FileMode.tree() + 1)
  end

  test "symlink?/1" do
    assert FileMode.symlink?(FileMode.symlink())
    refute FileMode.symlink?(FileMode.symlink() + 1)
  end

  test "regular_file?/1" do
    assert FileMode.regular_file?(FileMode.regular_file())
    refute FileMode.regular_file?(FileMode.regular_file() + 1)
  end

  test "executable_file?/1" do
    assert FileMode.executable_file?(FileMode.executable_file())
    refute FileMode.executable_file?(FileMode.executable_file() + 1)
  end

  test "gitlink?/1" do
    assert FileMode.gitlink?(FileMode.gitlink())
    refute FileMode.gitlink?(FileMode.gitlink() + 1)
  end

  test "valid?/1" do
    assert FileMode.valid?(FileMode.tree())
    refute FileMode.valid?(FileMode.tree() + 1)

    assert FileMode.valid?(FileMode.symlink())
    refute FileMode.valid?(FileMode.symlink() + 1)

    assert FileMode.valid?(FileMode.regular_file())
    refute FileMode.valid?(FileMode.regular_file() + 1)

    assert FileMode.valid?(FileMode.executable_file())
    refute FileMode.valid?(FileMode.executable_file() + 1)

    assert FileMode.valid?(FileMode.gitlink())
    refute FileMode.valid?(FileMode.gitlink() + 1)
  end

  test "to_octal/1" do
    assert FileMode.to_octal(FileMode.tree()) == '040000'
    assert FileMode.to_octal(FileMode.symlink()) == '120000'
    assert FileMode.to_octal(FileMode.regular_file()) == '100644'
    assert FileMode.to_octal(FileMode.executable_file()) == '100755'
    assert FileMode.to_octal(FileMode.gitlink()) == '160000'

    assert_raise FunctionClauseError, fn ->
      FileMode.to_octal(FileMode.gitlink() + 1)
    end
  end

  @valid_file_modes [0o040000, 0o120000, 0o100644, 0o100755, 0o160000]

  defp accepted_file_mode?(t) when is_file_mode(t), do: true
  defp accepted_file_mode?(_), do: false

  describe "is_file_mode/1" do
    test "accepts known file modes" do
      for t <- @valid_file_modes do
        assert accepted_file_mode?(t)
      end
    end

    test "rejects invalid values" do
      refute accepted_file_mode?(:mumble)
      refute accepted_file_mode?(0)
      refute accepted_file_mode?(1)
      refute accepted_file_mode?(0o100645)
      refute accepted_file_mode?("blob")
      refute accepted_file_mode?('blob')
      refute accepted_file_mode?(%{blob: true})
      refute accepted_file_mode?({:blob})
      refute accepted_file_mode?(fn -> :blob end)
      refute accepted_file_mode?(self())
    end
  end
end
