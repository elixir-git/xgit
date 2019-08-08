# Copyright (C) 2008-2010, Google Inc.
# Copyright (C) 2008, Shawn O. Pearce <spearce@spearce.org>
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit.test/tst/org/eclipse/jgit/lib/ObjectCheckerTest.java
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

defmodule Xgit.Core.ValidateObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Object

  import Xgit.Core.ValidateObject

  @placeholder_object_id 0..19 |> Enum.to_list()

  test "invalid object type" do
    assert {:error, :invalid_type} = check(%Object{type: :bad, content: []})
  end

  describe "check blob" do
    test "any blob should pass" do
      assert :ok = check(%Object{type: :blob, content: [0]})
      assert :ok = check(%Object{type: :blob, content: [1]})
      assert :ok = check(%Object{type: :blob, content: 'whatever'})
    end
  end

  describe "check commit" do
    test "valid: no parent" do
      assert :ok =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 committer A. U. Thor <author@localhost> 1 +0000
                 """
               })
    end

    test "valid: blank author" do
      assert :ok =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author <> 0 +0000
                 committer <> 0 +0000
                 """
               })
    end

    test "invalid: corrupt author" do
      assert {:error, "bad date"} =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author b <b@c> <b@c> 0 +0000
                 committer <> 0 +0000
                 """
               })
    end

    test "invalid: corrupt committer" do
      assert {:error, "bad date"} =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author <> 0 +0000
                 committer b <b@c> <b@c> 0 +0000
                 """
               })
    end

    test "valid: one parent" do
      assert :ok =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 committer A. U. Thor <author@localhost> 1 +0000
                 """
               })
    end

    test "valid: two parents" do
      assert :ok =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 committer A. U. Thor <author@localhost> 1 +0000
                 """
               })
    end

    test "valid: 128 parents" do
      data =
        'tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
          (1..128
           |> Enum.map(fn _ -> 'parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' end)
           |> Enum.concat()) ++
          'author A. U. Thor <author@localhost> 1 +0000\n' ++
          'committer A. U. Thor <author@localhost> 1 +0000\n'

      assert :ok = check(%Object{type: :commit, content: data})
    end

    test "valid: normal time" do
      assert :ok =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1222757360 -0730
                 committer A. U. Thor <author@localhost> 1222757360 -0730
                 """
               })
    end

    test "invalid: no tree 1" do
      assert {:error, :no_tree_header} =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 parent be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no tree 2" do
      assert {:error, :no_tree_header} =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 trie be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no tree 3" do
      assert {:error, :no_tree_header} =
               check(%Object{
                 type: :commit,
                 content: ~C"""
                 treebe9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no tree 4" do
      assert {:error, :no_tree_header} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree\tbe9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid tree 1" do
      assert {:error, :invalid_tree} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree zzzzfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid tree 2" do
      assert {:error, :invalid_tree} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189z
                 """
               })
    end

    test "invalid: invalid tree 3" do
      assert {:error, :invalid_tree} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9b
                 """
               })
    end

    test "invalid: invalid tree 4" do
      assert {:error, :invalid_tree} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree  be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid parent 1" do
      assert {:error, :invalid_parent} =
               check(%Object{
                 type: :commit,
                 content:
                   'tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'parent \n'
               })
    end

    test "invalid: invalid parent 2" do
      assert {:error, :invalid_parent} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent zzzzfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid parent 3" do
      assert {:error, :invalid_parent} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent  be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: invalid parent 4" do
      assert {:error, :invalid_parent} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent  be9bfa841874ccc9f2ef7c48d0c76226f89b7189z
                 """
               })
    end

    test "invalid: invalid parent 5" do
      # Yes, really, we complain about author not being
      # found as the invalid parent line wasn't consumed.

      assert {:error, :no_author} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 parent\tbe9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no author" do
      assert {:error, :no_author} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 committer A. U. Thor <author@localhost> 1 +0000
                 """
               })
    end

    test "invalid: no committer 1" do
      assert {:error, :no_committer} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000
                 """
               })
    end

    test "invalid: no committer 2" do
      assert {:error, :no_committer} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <author@localhost> 1 +0000

                 """
               })
    end

    test "invalid: invalid author 1" do
      assert {:error, "bad email"} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor <foo 1 +0000
                 """
               })
    end

    test "invalid: invalid author 2" do
      assert {:error, "missing email"} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author A. U. Thor foo> 1 +0000
                 """
               })
    end

    test "invalid: invalid author 3" do
      assert {:error, "missing email"} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author 1 +0000
                 """
               })
    end

    test "invalid: invalid author 4" do
      assert {:error, "bad date"} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author a <b> +0000
                 """
               })
    end

    test "invalid: invalid author 5" do
      assert {:error, "missing space before date"} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author a <b>
                 """
               })
    end

    test "invalid: invalid author 6" do
      assert {:error, "bad date"} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author a <b> z
                 """
               })
    end

    test "invalid: invalid author 7" do
      assert {:error, "bad time zone"} =
               check(%Object{
                 type: :commit,
                 content: ~c"""
                 tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 author a <b> 1 z
                 """
               })
    end

    test "invalid: invalid committer" do
      assert {:error, "bad email"} =
               check(%Object{
                 type: :commit,
                 content:
                   'tree be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'author a <b> 1 +0000\n' ++
                     'committer a <'
               })
    end
  end

  describe "check tag" do
    test "valid" do
      assert :ok =
               check(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tag test-tag
                 tagger A. U. Thor <author@localhost> 1 +0000
                 """
               })
    end

    test "invalid: no object 1" do
      assert {:error, :no_object_header} = check(%Object{type: :tag, content: []})
    end

    test "invalid: no object 2" do
      assert {:error, :no_object_header} =
               check(%Object{
                 type: :tag,
                 content: 'object\tbe9bfa841874ccc9f2ef7c48d0c76226f89b7189\n'
               })
    end

    test "invalid: no object 3" do
      assert {:error, :no_object_header} =
               check(%Object{
                 type: :tag,
                 content: ~c"""
                 obejct be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no object 4" do
      assert {:error, :invalid_object} =
               check(%Object{
                 type: :tag,
                 content: ~c"""
                 object zz9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no object 5" do
      assert {:error, :invalid_object} =
               check(%Object{
                 type: :tag,
                 content: 'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189 \n'
               })
    end

    test "invalid: no object 6" do
      assert {:error, :invalid_object} = check(%Object{type: :tag, content: 'object be9'})
    end

    test "invalid: no type 1" do
      assert {:error, :no_type_header} =
               check(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no type 2" do
      assert {:error, :no_type_header} =
               check(%Object{
                 type: :tag,
                 content:
                   'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'type\tcommit\n'
               })
    end

    test "invalid: no type 3" do
      assert {:error, :no_type_header} =
               check(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 tpye commit
                 """
               })
    end

    test "invalid: no type 4" do
      assert {:error, :no_tag_header} =
               check(%Object{
                 type: :tag,
                 content:
                   'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'type commit'
               })
    end

    test "invalid: no tag header 1" do
      assert {:error, :no_tag_header} =
               check(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 """
               })
    end

    test "invalid: no tag header 2" do
      assert {:error, :no_tag_header} =
               check(%Object{
                 type: :tag,
                 content:
                   'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'type commit\n' ++
                     'tag\tfoo\n'
               })
    end

    test "invalid: no tag header 3" do
      assert {:error, :no_tag_header} =
               check(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tga foo
                 """
               })
    end

    test "valid: has no tagger header" do
      assert :ok =
               check(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tag foo
                 """
               })
    end

    test "invalid: invalid tagger header 1" do
      assert {:error, :invalid_tagger} =
               check(%Object{
                 type: :tag,
                 content:
                   'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'type commit\n' ++
                     'tag foo\n' ++
                     'tagger \n'
               })
    end

    test "invalid: invalid tagger header 3" do
      assert {:error, :invalid_tagger} =
               check(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tag foo
                 tagger a < 1 +000
                 """
               })
    end
  end

  describe "check tree" do
    test "valid: empty tree" do
      assert :ok = check(%Object{type: :tree, content: []})
    end

    test "valid tree 1" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 regular-file")
               })
    end

    test "valid tree 2" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100755 executable")
               })
    end

    test "valid tree 3" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("40000 tree")
               })
    end

    test "valid tree 4" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("120000 symlink")
               })
    end

    test "valid tree 5" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("160000 git link")
               })
    end

    test "valid tree 6" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .a")
               })
    end

    test "valid: .gitmodules" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .gitmodules")
               })
    end

    test "invalid: null SHA-1 in tree entry" do
      assert {:error, "entry points to null SHA-1"} =
               check(%Object{
                 type: :tree,
                 content: '100644 A' ++ Enum.map(0..20, fn _ -> 0 end)
               })
    end

    test "valid: posix names" do
      check_one_name("a<b>c:d|e")
      check_one_name("test ")
      check_one_name("test.")
      check_one_name("NUL")
    end

    test "valid: sorting 1" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 fooaaa") ++ entry("100755 foobar")
               })
    end

    test "valid: sorting 2" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100755 fooaaa") ++ entry("100644 foobar")
               })
    end

    test "valid: sorting 3" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("40000 a") ++ entry("100644 b")
               })
    end

    test "valid: sorting 4" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 a") ++ entry("40000 b")
               })
    end

    test "valid: sorting 5" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 a.c") ++ entry("40000 a") ++ entry("100644 a0c")
               })
    end

    test "valid: sorting 6" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("40000 a") ++ entry("100644 apple")
               })
    end

    test "valid: sorting 7" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("40000 an orang") ++ entry("40000 an orange")
               })
    end

    test "valid: sorting 8" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 a") ++ entry("100644 a0c") ++ entry("100644 b")
               })
    end

    test "invalid: truncated in mode" do
      assert {:error, "truncated in mode"} =
               check(%Object{
                 type: :tree,
                 content: '1006'
               })
    end

    test "invalid: mode starts with zero 1" do
      assert {:error, "mode starts with '0'"} =
               check(%Object{
                 type: :tree,
                 content: entry("0 a")
               })
    end

    test "invalid: mode starts with zero 2" do
      assert {:error, "mode starts with '0'"} =
               check(%Object{
                 type: :tree,
                 content: entry("0100644 a")
               })
    end

    test "invalid: mode starts with zero 3" do
      assert {:error, "mode starts with '0'"} =
               check(%Object{
                 type: :tree,
                 content: entry("040000 a")
               })
    end

    test "invalid: mode not octal 1" do
      assert {:error, "invalid mode character"} =
               check(%Object{
                 type: :tree,
                 content: entry("8 a")
               })
    end

    test "invalid: mode not octal 2" do
      assert {:error, "invalid mode character"} =
               check(%Object{
                 type: :tree,
                 content: entry("Z a")
               })
    end

    test "invalid: mode not supported mode 1" do
      assert {:error, :invalid_file_mode} =
               check(%Object{
                 type: :tree,
                 content: entry("1 a")
               })
    end

    test "invalid: mode not supported mode 2" do
      assert {:error, :invalid_file_mode} =
               check(%Object{
                 type: :tree,
                 content: entry("170000 a")
               })
    end

    test "invalid: name contains slash" do
      assert {:error, :invalid_name} =
               check(%Object{
                 type: :tree,
                 content: entry("100644 a/b")
               })
    end

    test "invalid: name is empty" do
      assert {:error, "zero length name"} =
               check(%Object{
                 type: :tree,
                 content: entry("100644 ")
               })
    end

    test "invalid: name is '.'" do
      assert {:error, "invalid name '.'"} =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .")
               })
    end

    test "invalid: name is '..'" do
      assert {:error, "invalid name '..'"} =
               check(%Object{
                 type: :tree,
                 content: entry("100644 ..")
               })
    end

    test "invalid: name is '.git'" do
      assert {:error, "invalid name '.git'"} =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .git")
               })
    end

    test "invalid: name is '.git' (mixed case)" do
      assert {:error, "invalid name '.GiT'"} =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .GiT")
               })
    end

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

    test "invalid: name is Mac HFS .git" do
      Enum.each(@mac_hfs_git_names, fn name ->
        data = entry("100644 #{name}")

        # This is fine on Posix.
        assert :ok = check(%Object{type: :tree, content: data})

        # Rejected on Mac OS.
        expected_error = "invalid name '#{name}' contains ignorable Unicode characters"

        assert {:error, ^expected_error} =
                 check(%Object{type: :tree, content: data}, macosx?: true)
      end)
    end

    test "invalid: name is Mac HFS .git with corrupt UTF-8 at end 1" do
      data = '100644 .git' ++ [0xEF] ++ '\0#{@placeholder_object_id}'

      # This is fine on Posix.
      assert :ok = check(%Object{type: :tree, content: data})

      # Rejected on Mac OS.
      expected_error =
        "invalid name contains byte sequence '0xef' which is not a valid UTF-8 character"

      assert {:error, ^expected_error} = check(%Object{type: :tree, content: data}, macosx?: true)
    end

    test "invalid: name is Mac HFS .git with corrupt UTF-8 at end 2" do
      data = '100644 .git' ++ [0xE2, 0xAB] ++ '\0#{@placeholder_object_id}'

      # This is fine on Posix.
      assert :ok = check(%Object{type: :tree, content: data})

      # Rejected on Mac OS.
      expected_error =
        "invalid name contains byte sequence '0xe2ab' which is not a valid UTF-8 character"

      assert {:error, ^expected_error} = check(%Object{type: :tree, content: data}, macosx?: true)
    end

    test "valid: name is not Mac HFS .git 1" do
      assert :ok =
               check(
                 %Object{
                   type: :tree,
                   content: entry("100644 .git\u200Cx")
                 },
                 macosx?: true
               )
    end

    test "valid: name is not Mac HFS .git 2" do
      assert :ok =
               check(
                 %Object{
                   type: :tree,
                   content: entry("100644 .kit\u200C")
                 },
                 macosx?: true
               )
    end

    test "valid: name is not Mac HFS .git (other platform)" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .git\u200C")
               })
    end

    @bad_dot_git_names [".git.", ".git ", ".git. ", ".git . "]

    test "invalid: tree name is variant of .git" do
      Enum.each(@bad_dot_git_names, fn bad_name ->
        expected_error = "invalid name '#{bad_name}'"

        assert {:error, ^expected_error} =
                 check(%Object{
                   type: :tree,
                   content: entry("100644 #{bad_name}")
                 })
      end)
    end

    test "valid: name is .git.." do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .git..")
               })
    end

    test "valid: name is .gitsomething" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .gitfoobar")
               })
    end

    test "valid: name is .git-space-something" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .gitfoo bar")
               })
    end

    test "valid: name is .gitfoobar." do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .gitfoobar.")
               })
    end

    test "valid: name is .gitfoobar.." do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 .gitfoobar..")
               })
    end

    @bad_dot_git_tilde_names ["GIT~1", "GiT~1"]

    test "invalid: tree name is variant of git~1" do
      Enum.each(@bad_dot_git_tilde_names, fn bad_name ->
        assert {:error, :invalid_name} =
                 check(%Object{
                   type: :tree,
                   content: entry("100644 #{bad_name}")
                 })
      end)
    end

    test "valid: name is GIT~11" do
      assert :ok =
               check(%Object{
                 type: :tree,
                 content: entry("100644 GIT~11")
               })
    end

    test "invalid: tree truncated in name" do
      assert {:error, "truncated in name"} =
               check(%Object{
                 type: :tree,
                 content: '100644 b'
               })
    end

    test "invalid: tree truncated in object ID" do
      assert {:error, "truncated in object id"} =
               check(%Object{
                 type: :tree,
                 content: '100644 b' ++ [0, 1, 2]
               })
    end

    @badly_sorted_trees [
      ["100644 foobar", "100644 fooaaa"],
      ["40000 a", "100644 a.c"],
      ["100644 a0c", "40000 a"]
    ]

    test "invalid: bad sorting" do
      Enum.each(@badly_sorted_trees, fn badly_sorted_names ->
        assert {:error, "incorrectly sorted"} =
                 check(%Object{
                   type: :tree,
                   content:
                     badly_sorted_names
                     |> Enum.map(&entry/1)
                     |> Enum.concat()
                 })
      end)
    end

    test "invalid: duplicate file name" do
      assert {:error, "duplicate entry names"} =
               check(%Object{
                 type: :tree,
                 content: entry("100644 a") ++ entry("100644 a")
               })
    end

    test "invalid: duplicate tree name" do
      assert {:error, "duplicate entry names"} =
               check(%Object{
                 type: :tree,
                 content: entry("40000 a") ++ entry("40000 a")
               })
    end

    test "invalid: duplicate names 2" do
      assert {:error, "duplicate entry names"} =
               check(%Object{
                 type: :tree,
                 content: entry("100644 a") ++ entry("100755 a")
               })
    end

    test "invalid: duplicate names 3" do
      assert {:error, "duplicate entry names"} =
               check(%Object{
                 type: :tree,
                 content: entry("100644 a") ++ entry("40000 a")
               })
    end

    test "invalid: duplicate names 4" do
      assert {:error, "duplicate entry names"} =
               check(%Object{
                 type: :tree,
                 content:
                   entry("100644 a") ++
                     entry("100644 a.c") ++
                     entry("100644 a.d") ++
                     entry("100644 a.e") ++
                     entry("40000 a") ++
                     entry("100644 zoo")
               })
    end

    test "invalid: duplicate names 5 (Windows case folding)" do
      assert {:error, "duplicate entry names"} =
               check(
                 %Object{
                   type: :tree,
                   content: entry("100644 A") ++ entry("100644 a")
                 },
                 windows?: true
               )
    end

    test "invalid: duplicate names 6 (Mac case folding)" do
      assert {:error, "duplicate entry names"} =
               check(
                 %Object{
                   type: :tree,
                   content: entry("100644 A") ++ entry("100644 a")
                 },
                 macosx?: true
               )
    end

    test "invalid: duplicate names 7 (MacOS denormalized names)" do
      assert {:error, "duplicate entry names"} =
               check(
                 %Object{
                   type: :tree,
                   content: entry("100644 \u0065\u0301") ++ entry("100644 \u00e9")
                 },
                 macosx?: true
               )
    end

    test "valid: Mac name checking enabled" do
      assert :ok =
               check(
                 %Object{
                   type: :tree,
                   content: entry("100644 A")
                 },
                 macosx?: true
               )
    end

    test "invalid: space at end on Windows" do
      assert {:error, "invalid name ends with ' '"} =
               check(
                 %Object{
                   type: :tree,
                   content: entry("100644 test ")
                 },
                 windows?: true
               )
    end

    test "invalid: dot at end on Windows" do
      assert {:error, "invalid name ends with '.'"} =
               check(
                 %Object{
                   type: :tree,
                   content: entry("100644 test.")
                 },
                 windows?: true
               )
    end

    @windows_device_names [
      "CON",
      "PRN",
      "AUX",
      "NUL",
      "COM1",
      "COM2",
      "COM3",
      "COM4",
      "COM5",
      "COM6",
      "COM7",
      "COM8",
      "COM9",
      "LPT1",
      "LPT2",
      "LPT3",
      "LPT4",
      "LPT5",
      "LPT6",
      "LPT7",
      "LPT8",
      "LPT9"
    ]

    test "invalid: device names on Windows" do
      Enum.each(@windows_device_names, fn name ->
        expected_error = "invalid name '#{name}'"

        assert {:error, ^expected_error} =
                 check(
                   %Object{
                     type: :tree,
                     content: entry("100644 #{name}")
                   },
                   windows?: true
                 )
      end)
    end

    @invalid_windows_chars ['<', '>', ':', '\"', '\\', '|', '?', '*']

    test "invalid: characters not allowed on Windows" do
      Enum.each(@invalid_windows_chars, fn c ->
        expected_error = "char '#{c}' not allowed in Windows filename"

        assert {:error, ^expected_error} =
                 check(
                   %Object{
                     type: :tree,
                     content: entry("100644 te#{c}st")
                   },
                   windows?: true
                 )
      end)

      Enum.each(1..31, fn b ->
        expected_error = "byte 0x'#{byte_to_hex(b)}' not allowed in Windows filename"

        assert {:error, ^expected_error} =
                 check(
                   %Object{
                     type: :tree,
                     content: entry("100644 te#{<<b>>}st")
                   },
                   windows?: true
                 )
      end)
    end
  end

  defp byte_to_hex(b) when b < 16, do: "0" <> integer_to_lc_hex_string(b)
  defp byte_to_hex(b), do: integer_to_lc_hex_string(b)

  defp integer_to_lc_hex_string(b), do: b |> Integer.to_string(16) |> String.downcase()

  defp check_one_name(name, opts \\ []),
    do: assert(:ok = check(%Object{type: :tree, content: entry("100644 #{name}")}, opts))

  defp entry(mode_and_name),
    do: :binary.bin_to_list(mode_and_name) ++ [0] ++ @placeholder_object_id
end
