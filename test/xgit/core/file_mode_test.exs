defmodule Xgit.Core.FileModeTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.FileMode

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
end
