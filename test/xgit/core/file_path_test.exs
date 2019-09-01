# Copyright (C) 2008-2010, Google Inc.
# Copyright (C) 2008, Shawn O. Pearce <spearce@spearce.org>
# Copyright (C) 2016, Google Inc.
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit files:
# org.eclipse.jgit.test/tst/org/eclipse/jgit/lib/ObjectCheckerTest.java
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

defmodule Xgit.Core.FilePathTest do
  use ExUnit.Case, async: true
  use Xgit.Core.FileMode

  import Xgit.Core.FilePath

  @windows_git_names ['GIT~1', 'GiT~1']
  @almost_windows_git_names ['GIT~11', 'GIT~2']

  @mac_hfs_git_names [
    ".gi\u200Ct",
    ".gi\u200Dt",
    ".gi\u200Et",
    ".gi\u200Ft",
    ".gi\u202At",
    ".gi\u202Bt",
    ".gi\u202Ct",
    ".gi\u202Dt",
    ".gi\u202Et",
    ".gi\u206At",
    "\u206B.git",
    "\u206C.git",
    "\u206D.git",
    "\u206E.git",
    "\u206F.git",
    ".git\uFEFF"
  ]

  @almost_mac_hfs_git_names [
    ".git\u200Cx",
    ".gi\u202Ft",
    ".gi\u2069t",
    ".gi\uFEC0t",
    ".kit\u200C"
  ]

  @git_special_names [
    '.',
    '..',
    '.git',
    '.git.',
    '.git ',
    '.git. ',
    '.git .',
    '.git . ',
    '.Git',
    '.gIt',
    '.giT',
    '.giT.'
  ]

  @almost_git_special_names [
    '.g',
    '.git..',
    '.gitfoobar',
    '.gitfoo bar',
    '.gitfoobar.',
    '.gitfoobar..'
  ]

  @windows_device_names ['aux', 'con', 'com1', 'com7', 'lpt1', 'lpt3', 'nul', 'prn']
  @almost_windows_device_names ['aub', 'con1', 'com', 'com0', 'lpt', 'nul3', 'prn8']

  @invalid_windows_chars [?", ?*, ?:, ?<, ?>, ??, ?\\, ?|, 1, 2, 3, 4, 7, 31]

  @ntfs_gitmodules [
    '.GITMODULES',
    '.gitmodules',
    '.Gitmodules',
    '.gitmoduleS',
    'gitmod~1',
    'GITMOD~1',
    'gitmod~4',
    'GI7EBA~1',
    'gi7eba~9',
    'GI7EB~10',
    'GI7E~123',
    'GI7~1234',
    'GI~12534',
    'G~912534',
    '~1000000',
    '~9999999'
  ]

  describe "valid?/2" do
    test "basic case: no platform checks" do
      refute valid?('')
      assert valid?('a')
      assert valid?('a/b')
      refute valid?('a//b')
      refute valid?('/a')
      refute valid?('a\0b')
      assert valid?('ab/cd/ef')

      refute valid?('ab/cd//ef')
      refute valid?('a/')
      refute valid?('ab/cd/ef/')
    end

    test "rejects paths that aren't byte lists" do
      refute valid?("a")
      refute valid?("a/b")
      refute valid?("ab/cd/ef")
      refute valid?(:a)
      refute valid?(true)
      refute valid?(42)
    end

    test "Windows variations on .git (applies to all platforms)" do
      for name <- @windows_git_names do
        refute valid?(name)
        refute valid?(name, windows?: true)
        refute valid?(name, macosx?: true)
      end

      for name <- @almost_windows_git_names do
        assert valid?(name)
        assert valid?(name, windows?: true)
        assert valid?(name, macosx?: true)
      end
    end

    test "variations on .git on Mac" do
      for name <- @mac_hfs_git_names do
        assert valid?(:binary.bin_to_list(name))
        refute valid?(:binary.bin_to_list(name), macosx?: true)
      end

      for name <- @almost_mac_hfs_git_names do
        assert valid?(:binary.bin_to_list(name))
        assert valid?(:binary.bin_to_list(name), macosx?: true)
      end
    end

    test "invalid Windows characters" do
      for char <- @invalid_windows_chars do
        assert valid?([char])
        assert valid?([?a, char, ?b])
        refute valid?([char], windows?: true)
        refute valid?([?a, char, ?b], windows?: true)
      end

      for char <- 1..31 do
        assert valid?([char])
        assert valid?([?a, char, ?b])
        refute valid?([char], windows?: true)
        refute valid?([?a, char, ?b], windows?: true)
      end
    end

    test "git special names" do
      for name <- @git_special_names do
        refute valid?(name)
      end

      for name <- @almost_git_special_names do
        assert valid?(name)
      end
    end

    test "badly-formed UTF8 on Mac" do
      refute valid?([?a, ?b, 0xE2, 0x80], macosx?: true)
      refute valid?([?a, ?b, 0xEF, 0x80], macosx?: true)
      assert valid?([?a, ?b, 0xE2, 0x80, 0xAE], macosx?: true)

      bad_name = '.git' ++ [0xEF]
      assert valid?(bad_name)
      refute valid?(bad_name, macosx?: true)

      bad_name = '.git' ++ [0xE2, 0xAB]
      assert valid?(bad_name)
      refute valid?(bad_name, macosx?: true)
    end

    test "Windows name ending with ." do
      assert valid?('abc.')
      assert valid?('abc ')

      refute valid?('abc.', windows?: true)
      refute valid?('abc ', windows?: true)
    end

    test "Windows device names" do
      for name <- @windows_device_names do
        assert valid?(name)
        refute valid?(name, windows?: true)
      end

      for name <- @almost_windows_device_names do
        assert valid?(name)
        assert valid?(name, windows?: true)
      end
    end
  end

  describe "check_path/2" do
    test "basic case: no platform checks" do
      assert check_path('') == {:error, :empty_path}
      assert check_path('a') == :ok
      assert check_path('a/b') == :ok
      assert check_path('a//b') == {:error, :duplicate_slash}
      assert check_path('/a') == {:error, :absolute_path}
      assert check_path('a\0b') == {:error, :invalid_name}
      assert check_path('ab/cd/ef') == :ok

      assert check_path('ab/cd//ef') == {:error, :duplicate_slash}
      assert check_path('a/') == {:error, :trailing_slash}
      assert check_path('ab/cd/ef/') == {:error, :trailing_slash}
    end

    test "Windows variations on .git (applies to all platforms)" do
      for name <- @windows_git_names do
        assert {:error, :invalid_name} = check_path(name)
        assert {:error, :invalid_name} = check_path(name, windows?: true)
        assert {:error, :invalid_name} = check_path(name, macosx?: true)
      end

      for name <- @almost_windows_git_names do
        assert :ok = check_path(name)
        assert :ok = check_path(name, windows?: true)
        assert :ok = check_path(name, macosx?: true)
      end
    end

    test "variations on .git on Mac" do
      for name <- @mac_hfs_git_names do
        assert :ok = check_path(:binary.bin_to_list(name))
        assert {:error, :reserved_name} = check_path(:binary.bin_to_list(name), macosx?: true)
      end

      for name <- @almost_mac_hfs_git_names do
        assert :ok = check_path(:binary.bin_to_list(name))
        assert :ok = check_path(:binary.bin_to_list(name), macosx?: true)
      end
    end

    test "invalid Windows characters" do
      for char <- @invalid_windows_chars do
        assert :ok = check_path([char])
        assert :ok = check_path([?a, char, ?b])
        assert {:error, :invalid_name_on_windows} = check_path([char], windows?: true)
        assert {:error, :invalid_name_on_windows} = check_path([?a, char, ?b], windows?: true)
      end

      for char <- 1..31 do
        assert :ok = check_path([char])
        assert :ok = check_path([?a, char, ?b])
        assert {:error, :invalid_name_on_windows} = check_path([char], windows?: true)
        assert {:error, :invalid_name_on_windows} = check_path([?a, char, ?b], windows?: true)
      end
    end

    test "git special names" do
      for name <- @git_special_names do
        assert {:error, :reserved_name} = check_path(name)
      end

      for name <- @almost_git_special_names do
        assert :ok = check_path(name)
      end
    end

    test "badly-formed UTF8 on Mac" do
      assert {:error, :invalid_utf8_sequence} = check_path([?a, ?b, 0xE2, 0x80], macosx?: true)
      assert {:error, :invalid_utf8_sequence} = check_path([?a, ?b, 0xEF, 0x80], macosx?: true)
      assert :ok = check_path([?a, ?b, 0xE2, 0x80, 0xAE], macosx?: true)

      bad_name = '.git' ++ [0xEF]
      assert :ok = check_path(bad_name)
      assert {:error, :invalid_utf8_sequence} = check_path(bad_name, macosx?: true)

      bad_name = '.git' ++ [0xE2, 0xAB]
      assert :ok = check_path(bad_name)
      assert {:error, :invalid_utf8_sequence} = check_path(bad_name, macosx?: true)
    end

    test "Windows name ending with ." do
      assert :ok = check_path('abc.')
      assert :ok = check_path('abc ')

      assert {:error, :invalid_name_on_windows} = check_path('abc.', windows?: true)
      assert {:error, :invalid_name_on_windows} = check_path('abc ', windows?: true)
    end

    test "Windows device names" do
      for name <- @windows_device_names do
        assert :ok = check_path(name)
        assert {:error, :windows_device_name} = check_path(name, windows?: true)
      end

      for name <- @almost_windows_device_names do
        assert :ok = check_path(name)
        assert :ok = check_path(name, windows?: true)
      end
    end
  end

  describe "check_path_segment/2" do
    test "basic case: no platform checks" do
      assert check_path_segment('') == {:error, :empty_name}
      assert check_path_segment('a') == :ok
      assert check_path_segment('a/b') == {:error, :invalid_name}
      assert check_path_segment('/a') == {:error, :invalid_name}
      assert check_path_segment('a\0b') == {:error, :invalid_name}
    end

    test "Windows variations on .git (applies to all platforms)" do
      for name <- @windows_git_names do
        assert {:error, :invalid_name} = check_path_segment(name)
        assert {:error, :invalid_name} = check_path_segment(name, windows?: true)
        assert {:error, :invalid_name} = check_path_segment(name, macosx?: true)
      end

      for name <- @almost_windows_git_names do
        assert :ok = check_path_segment(name)
        assert :ok = check_path_segment(name, windows?: true)
        assert :ok = check_path_segment(name, macosx?: true)
      end
    end

    test "variations on .git on Mac" do
      for name <- @mac_hfs_git_names do
        assert {:error, :reserved_name} =
                 check_path_segment(:binary.bin_to_list(name), macosx?: true)
      end
    end

    test "invalid Windows characters" do
      for char <- @invalid_windows_chars do
        assert :ok = check_path_segment([char])
        assert :ok = check_path_segment([?a, char, ?b])
        assert {:error, :invalid_name_on_windows} = check_path_segment([char], windows?: true)

        assert {:error, :invalid_name_on_windows} =
                 check_path_segment([?a, char, ?b], windows?: true)
      end

      for char <- 1..31 do
        assert :ok = check_path_segment([char])
        assert :ok = check_path_segment([?a, char, ?b])
        assert {:error, :invalid_name_on_windows} = check_path_segment([char], windows?: true)

        assert {:error, :invalid_name_on_windows} =
                 check_path_segment([?a, char, ?b], windows?: true)
      end
    end

    test "git special names" do
      for name <- @git_special_names do
        assert {:error, :reserved_name} = check_path_segment(name)
      end

      for name <- @almost_git_special_names do
        assert :ok = check_path_segment(name)
      end
    end

    test "badly-formed UTF8 on Mac" do
      assert {:error, :invalid_utf8_sequence} =
               check_path_segment([?a, ?b, 0xE2, 0x80], macosx?: true)

      assert {:error, :invalid_utf8_sequence} =
               check_path_segment([?a, ?b, 0xEF, 0x80], macosx?: true)

      assert :ok = check_path_segment([?a, ?b, 0xE2, 0x80, 0xAE], macosx?: true)

      bad_name = '.git' ++ [0xEF]
      assert :ok = check_path_segment(bad_name)
      assert {:error, :invalid_utf8_sequence} = check_path_segment(bad_name, macosx?: true)

      bad_name = '.git' ++ [0xE2, 0xAB]
      assert :ok = check_path_segment(bad_name)
      assert {:error, :invalid_utf8_sequence} = check_path_segment(bad_name, macosx?: true)
    end

    test "Windows name ending with . or space" do
      assert :ok = check_path_segment('abc.')
      assert :ok = check_path_segment('abc ')

      assert {:error, :invalid_name_on_windows} = check_path_segment('abc.', windows?: true)
      assert {:error, :invalid_name_on_windows} = check_path_segment('abc ', windows?: true)
    end

    test "Windows device names" do
      for name <- @windows_device_names do
        assert :ok = check_path_segment(name)
        assert {:error, :windows_device_name} = check_path_segment(name, windows?: true)
      end

      for name <- @almost_windows_device_names do
        assert :ok = check_path_segment(name)
        assert :ok = check_path_segment(name, windows?: true)
      end
    end

    test "rejects path with slash" do
      assert check_path_segment('a/b') == {:error, :invalid_name}
    end

    test "rejects empty segment" do
      assert check_path_segment([]) == {:error, :empty_name}
    end

    test "jgit bug 477090" do
      # U+221E 0xe2889e INFINITY ∞ .html
      bytes = [0xE2, 0x88, 0x9E, 0x2E, 0x68, 0x74, 0x6D, 0x6C]
      assert :ok = check_path_segment(bytes, macosx?: true)
    end
  end

  describe "gitmodules?/2" do
    test "basic case: no platform checks" do
      assert gitmodules?('.gitmodules')
      refute gitmodules?('.git')
      refute gitmodules?('.gitmodulesx')
      refute gitmodules?('.Gitmodules')
    end

    test "Mac case folding" do
      assert gitmodules?('.gitmodules', macosx?: true)
      assert gitmodules?('.Gitmodules', macosx?: true)
      assert gitmodules?('.GitModules', macosx?: true)
      refute gitmodules?('.GitModulesx', macosx?: true)
      refute gitmodules?('.git', macosx?: true)
      refute gitmodules?('.gitmodulesx', macosx?: true)
    end

    test "NTFS short names" do
      for name <- @ntfs_gitmodules do
        assert gitmodules?(name, windows?: true)
      end

      refute gitmodules?('.git', windows?: true)
      refute gitmodules?('.gitmodulesx', windows?: true)
      refute gitmodules?('.gitmodu', windows?: true)

      assert gitmodules?('.GITMODULES', windows?: true)
      refute gitmodules?('.GITMODULES')

      refute gitmodules?('GI7E~012', windows?: true)
      refute gitmodules?('GI7E~12X', windows?: true)
    end
  end

  describe "strip_trailing_separator/1" do
    test "empty list" do
      assert strip_trailing_separator([]) == []
    end

    test "without trailing /" do
      assert strip_trailing_separator('abc') == 'abc'
      assert strip_trailing_separator('/abc') == '/abc'
      assert strip_trailing_separator('foo/b') == 'foo/b'
    end

    test "with trailing /" do
      assert strip_trailing_separator('/') == []
      assert strip_trailing_separator('abc/') == 'abc'
      assert strip_trailing_separator('foo/bar//') == 'foo/bar'
    end
  end

  describe "compare/4" do
    test "simple case (paths don't match)" do
      assert compare('abc', FileMode.regular_file(), 'def', FileMode.regular_file()) == :lt
      assert compare('abc', FileMode.regular_file(), 'aba', FileMode.regular_file()) == :gt
    end

    test "lengths mismatch" do
      assert compare('abc', FileMode.regular_file(), 'ab', FileMode.regular_file()) == :gt
      assert compare('ab', FileMode.regular_file(), 'aba', FileMode.regular_file()) == :lt
    end

    test "implied / for file tree" do
      assert compare('ab/', FileMode.tree(), 'ab', FileMode.tree()) == :eq
      assert compare('ab', FileMode.tree(), 'ab/', FileMode.tree()) == :eq
    end

    test "exact match" do
      assert compare('abc', FileMode.regular_file(), 'abc', FileMode.regular_file()) == :eq
    end

    test "match except for file mode" do
      assert compare('abc', FileMode.tree(), 'abc', FileMode.regular_file()) == :gt
      assert compare('abc', FileMode.regular_file(), 'abc', FileMode.tree()) == :lt
    end

    test "gitlink exception" do
      assert compare('abc', FileMode.tree(), 'abc', FileMode.gitlink()) == :eq
      assert compare('abc', FileMode.gitlink(), 'abc', FileMode.tree()) == :eq
    end
  end

  describe "compare_same_name/3" do
    test "simple case (paths don't match)" do
      assert compare_same_name('abc', 'def', FileMode.regular_file()) == :lt
      assert compare_same_name('abc', 'aba', FileMode.regular_file()) == :gt
    end

    test "lengths mismatch" do
      assert compare_same_name('abc', 'ab', FileMode.regular_file()) == :gt
      assert compare_same_name('ab', 'aba', FileMode.regular_file()) == :lt
    end

    test "implied / for file tree" do
      assert compare_same_name('ab/', 'ab', FileMode.tree()) == :eq
      assert compare_same_name('ab', 'ab/', FileMode.tree()) == :eq
    end

    test "exact match, different type" do
      assert compare_same_name('abc', 'abc', FileMode.regular_file()) == :eq
    end

    test "exact match, same type" do
      assert compare_same_name('abc', 'abc', FileMode.tree()) == :eq
    end

    test "match except for file mode" do
      assert compare_same_name('abc', 'abc', FileMode.regular_file()) == :eq
    end

    test "gitlink exception" do
      assert compare_same_name('abc', 'abc', FileMode.gitlink()) == :eq
    end
  end
end
