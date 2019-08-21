# Copyright (C) 2008, 2015 Google Inc.
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit.test/tst/org/eclipse/jgit/util/NBTest.java
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

defmodule Xgit.Util.NBTest do
  use ExUnit.Case, async: true

  alias Xgit.Util.NB

  describe "decode_int32/1" do
    test "simple cases" do
      assert NB.decode_int32([0, 0, 0, 0, 0]) == {0, [0]}
      assert NB.decode_int32([0, 0, 0, 0, 3]) == {0, [3]}

      assert NB.decode_int32([0, 0, 0, 0, 3, 42]) == {0, [3, 42]}

      assert NB.decode_int32([0, 0, 0, 3]) == {3, []}
      assert NB.decode_int32([0, 0, 0, 3, 0]) == {3, [0]}
      assert NB.decode_int32([0, 0, 0, 3, 3]) == {3, [3]}

      assert NB.decode_int32([0x03, 0x10, 0xAD, 0xEF, 1]) == {0x0310ADEF, [1]}
    end

    test "negative numbers" do
      assert NB.decode_int32([0xFF, 0xFF, 0xFF, 0xFF, 0xFE]) == {-1, [0xFE]}
      assert NB.decode_int32([0xDE, 0xAD, 0xBE, 0xEF, 1]) == {-559_038_737, [1]}
    end

    test "rejects byte list too short" do
      assert_raise FunctionClauseError, fn ->
        NB.decode_int32([1, 2, 3])
      end
    end
  end

  describe "decode_uint16/1" do
    test "simple cases" do
      assert NB.decode_uint16([0, 0, 0]) == {0, [0]}
      assert NB.decode_uint16([0, 0, 3]) == {0, [3]}

      assert NB.decode_uint16([0, 0, 3, 42]) == {0, [3, 42]}

      assert NB.decode_uint16([0, 3]) == {3, []}
      assert NB.decode_uint16([0, 3, 0]) == {3, [0]}
      assert NB.decode_uint16([0, 3, 3]) == {3, [3]}

      assert NB.decode_uint16([0xAD, 0xEF, 1]) == {0xADEF, [1]}

      assert NB.decode_uint16([0xFF, 0xFF, 0xFE]) == {0xFFFF, [0xFE]}
      assert NB.decode_uint16([0xBE, 0xEF, 1]) == {0xBEEF, [1]}
    end

    test "rejects byte list too short" do
      assert_raise FunctionClauseError, fn ->
        NB.decode_uint16([1])
      end
    end
  end

  describe "decode_uint32/1" do
    test "simple cases" do
      assert NB.decode_uint32([0, 0, 0, 0, 0]) == {0, [0]}
      assert NB.decode_uint32([0, 0, 0, 0, 3]) == {0, [3]}

      assert NB.decode_uint32([0, 0, 0, 0, 3, 42]) == {0, [3, 42]}

      assert NB.decode_uint32([0, 0, 0, 3]) == {3, []}
      assert NB.decode_uint32([0, 0, 0, 3, 0]) == {3, [0]}
      assert NB.decode_uint32([0, 0, 0, 3, 3]) == {3, [3]}

      assert NB.decode_uint32([0x03, 0x10, 0xAD, 0xEF, 1]) == {0x0310ADEF, [1]}

      assert NB.decode_uint32([0xFF, 0xFF, 0xFF, 0xFF, 0xFE]) == {0xFFFFFFFF, [0xFE]}
      assert NB.decode_uint32([0xDE, 0xAD, 0xBE, 0xEF, 1]) == {0xDEADBEEF, [1]}
    end

    test "rejects byte list too short" do
      assert_raise FunctionClauseError, fn ->
        NB.decode_uint32([1, 2, 3])
      end
    end
  end

  test "encode_int16/1" do
    assert NB.encode_int16(0) == [0, 0]
    assert NB.encode_int16(3) == [0, 3]
    assert NB.encode_int16(0xDEAC) == [0xDE, 0xAC]
    assert NB.encode_int16(-1) == [0xFF, 0xFF]
  end

  test "encode_int32/1" do
    assert NB.encode_int32(0) == [0, 0, 0, 0]
    assert NB.encode_int32(3) == [0, 0, 0, 3]
    assert NB.encode_int32(0xDEAC) == [0, 0, 0xDE, 0xAC]
    assert NB.encode_int32(0xDEAC9853) == [0xDE, 0xAC, 0x98, 0x53]
    assert NB.encode_int32(-1) == [0xFF, 0xFF, 0xFF, 0xFF]
  end

  test "encode_uint32/1" do
    assert NB.encode_uint32(0) == [0, 0, 0, 0]
    assert NB.encode_uint32(3) == [0, 0, 0, 3]
    assert NB.encode_uint32(0xDEAC) == [0, 0, 0xDE, 0xAC]
    assert NB.encode_uint32(0xDEAC9853) == [0xDE, 0xAC, 0x98, 0x53]

    assert_raise FunctionClauseError, fn -> NB.encode_uint32(-1) end
  end
end
