# Copyright (C) 2016, Google Inc.
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit.test/tst/org/eclipse/jgit/util/PathsTest.java
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

defmodule Xgit.Util.PathsTest do
  use ExUnit.Case, async: true
  use Xgit.Core.FileMode

  alias Xgit.Util.Paths

  describe "strip_trailing_separator/1" do
    test "empty list" do
      assert Paths.strip_trailing_separator([]) == []
    end

    test "without trailing /" do
      assert Paths.strip_trailing_separator('abc') == 'abc'
      assert Paths.strip_trailing_separator('/abc') == '/abc'
      assert Paths.strip_trailing_separator('foo/b') == 'foo/b'
    end

    test "with trailing /" do
      assert Paths.strip_trailing_separator('/') == []
      assert Paths.strip_trailing_separator('abc/') == 'abc'
      assert Paths.strip_trailing_separator('foo/bar//') == 'foo/bar'
    end
  end

  describe "compare/4" do
    test "simple case (paths don't match)" do
      assert Paths.compare('abc', FileMode.regular_file(), 'def', FileMode.regular_file()) == :lt
      assert Paths.compare('abc', FileMode.regular_file(), 'aba', FileMode.regular_file()) == :gt
    end

    test "lengths mismatch" do
      assert Paths.compare('abc', FileMode.regular_file(), 'ab', FileMode.regular_file()) == :gt
      assert Paths.compare('ab', FileMode.regular_file(), 'aba', FileMode.regular_file()) == :lt
    end

    test "implied / for file tree" do
      assert Paths.compare('ab/', FileMode.tree(), 'ab', FileMode.tree()) == :eq
      assert Paths.compare('ab', FileMode.tree(), 'ab/', FileMode.tree()) == :eq
    end

    test "exact match" do
      assert Paths.compare('abc', FileMode.regular_file(), 'abc', FileMode.regular_file()) == :eq
    end

    test "match except for file mode" do
      assert Paths.compare('abc', FileMode.tree(), 'abc', FileMode.regular_file()) == :gt
      assert Paths.compare('abc', FileMode.regular_file(), 'abc', FileMode.tree()) == :lt
    end

    test "gitlink exception" do
      assert Paths.compare('abc', FileMode.tree(), 'abc', FileMode.gitlink()) == :eq
      assert Paths.compare('abc', FileMode.gitlink(), 'abc', FileMode.tree()) == :eq
    end
  end

  describe "compare_same_name/3" do
    test "simple case (paths don't match)" do
      assert Paths.compare_same_name('abc', 'def', FileMode.regular_file()) == :lt
      assert Paths.compare_same_name('abc', 'aba', FileMode.regular_file()) == :gt
    end

    test "lengths mismatch" do
      assert Paths.compare_same_name('abc', 'ab', FileMode.regular_file()) == :gt
      assert Paths.compare_same_name('ab', 'aba', FileMode.regular_file()) == :lt
    end

    test "implied / for file tree" do
      assert Paths.compare_same_name('ab/', 'ab', FileMode.tree()) == :eq
      assert Paths.compare_same_name('ab', 'ab/', FileMode.tree()) == :eq
    end

    test "exact match, different type" do
      assert Paths.compare_same_name('abc', 'abc', FileMode.regular_file()) == :eq
    end

    test "exact match, same type" do
      assert Paths.compare_same_name('abc', 'abc', FileMode.tree()) == :eq
    end

    test "match except for file mode" do
      assert Paths.compare_same_name('abc', 'abc', FileMode.regular_file()) == :eq
    end

    test "gitlink exception" do
      assert Paths.compare_same_name('abc', 'abc', FileMode.gitlink()) == :eq
    end
  end
end
