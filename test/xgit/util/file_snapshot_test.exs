# Copyright (C) 2010, Robin Rosenberg
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit.test/tst/org/eclipse/jgit/internal/storage/file/FileSnapshotTest.java
#
# Copyright (C) 2019, Eric Scouten <eric+xgit@scouten.com>
#
# This program and the accompanying materials are made available
# under the terms of the Eclipse Distribution License v1.0 which
# accompanies this distribution, is reproduced below, and is
# available at http://www.eclipse.org/org/documents/edl-v10.php
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# - Redistributions in binary form must reproduce the above
#   copyright notice, this list of conditions and the following
#   disclaimer in the documentation and/or other materials provided
#   with the distribution.
#
# - Neither the name of the Eclipse Foundation, Inc. nor the
#   names of its contributors may be used to endorse or promote
#   products derived from this software without specific prior
#   written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

defmodule Xgit.Util.FileSnapshotTest do
  use ExUnit.Case, async: true

  alias Xgit.Util.FileSnapshot

  setup do
    Temp.track!()
    temp_file_path = Temp.mkdir!(prefix: "tmp_")
    {:ok, trash: temp_file_path}
  end

  defp wait_next_sec(f) when is_binary(f) do
    %{mtime: initial_last_modified} = File.stat!(f, time: :posix)
    wait_next_sec(f, initial_last_modified)
  end

  defp wait_next_sec(f, initial_last_modified) do
    time_now = :os.system_time(:second)

    if time_now <= initial_last_modified do
      Process.sleep(100)
      wait_next_sec(f, initial_last_modified)
    end
  end

  test "missing_file/0", %{trash: trash} do
    missing = FileSnapshot.missing_file()
    path = Temp.path!()

    refute FileSnapshot.modified?(missing, path)

    f1 = create_file!(trash, "missing")
    assert FileSnapshot.modified?(missing, f1)

    assert to_string(missing) == "MISSING_FILE"
  end

  test "actually is modified (trivial case)", %{trash: trash} do
    f1 = create_file!(trash, "simple")
    wait_next_sec(f1)

    save = FileSnapshot.save(f1)
    append!(f1, 'x')

    wait_next_sec(f1)

    assert FileSnapshot.modified?(save, f1) == true

    assert String.starts_with?(to_string(save), "FileSnapshot")
  end

  test "new file without significant wait", %{trash: trash} do
    f1 = create_file!(trash, "newfile")
    wait_next_sec(f1)

    save = FileSnapshot.save(f1)

    Process.sleep(1500)
    assert FileSnapshot.modified?(save, f1) == true
  end

  test "new file without wait", %{trash: trash} do
    # Same as above but do not wait at all.

    f1 = create_file!(trash, "newfile")
    wait_next_sec(f1)

    save = FileSnapshot.save(f1)
    assert FileSnapshot.modified?(save, f1) == true
  end

  test "dirty snapshot is always dirty", %{trash: trash} do
    f1 = create_file!(trash, "newfile")
    wait_next_sec(f1)

    dirty = FileSnapshot.dirty()
    assert FileSnapshot.modified?(dirty, f1) == true

    assert to_string(dirty) == "DIRTY"
  end

  describe "set_clean/2" do
    test "without delay", %{trash: trash} do
      f1 = create_file!(trash, "newfile")
      wait_next_sec(f1)

      save = FileSnapshot.save(f1)
      assert FileSnapshot.modified?(save, f1) == true

      # an abuse of the API, but best we can do
      FileSnapshot.set_clean(save, save)
      assert FileSnapshot.modified?(save, f1) == false
    end

    test "with (faked) delay", %{trash: trash} do
      f1 = create_file!(trash, "newfile")
      wait_next_sec(f1)

      save = FileSnapshot.save(f1)
      assert FileSnapshot.modified?(save, f1) == true

      modified_earlier = %{save | last_modified: save.last_modified - 10}
      FileSnapshot.set_clean(modified_earlier, save)
      assert FileSnapshot.modified?(modified_earlier, f1) == true
    end
  end

  defp create_file!(trash, leaf_name) when is_binary(trash) and is_binary(leaf_name) do
    path = Path.expand(leaf_name, trash)
    File.touch!(path)
    path
  end

  defp append!(path, b) when is_binary(path) and is_list(b), do: File.write!(path, b, [:append])
end
