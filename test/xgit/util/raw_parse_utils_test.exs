# Copyright (C) 2009, Google Inc.
# Copyright (C) 2010, Marc Strapetz <marc.strapetz@syntevo.com>
# Copyright (C) 2011, Leonard Broman <leonard.broman@gmail.com>
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit files:
# org.eclipse.jgit.test/tst/org/eclipse/jgit/util/RawParseUtilsTest.java
# org.eclipse.jgit.test/tst/org/eclipse/jgit/util/RawParseUtils_MatchTest.java
# org.eclipse.jgit.test/tst/org/eclipse/jgit/util/RawParseUtils_ParsePersonIdentTest.java
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

defmodule Xgit.Util.RawParseUtilsTest do
  use ExUnit.Case, async: true

  alias Xgit.Util.RawParseUtils, as: RPU

  test "parse_base_10/1" do
    assert RPU.parse_base_10('abc') == {0, 'abc'}
    assert RPU.parse_base_10('0abc') == {0, 'abc'}
    assert RPU.parse_base_10('99') == {99, ''}
    assert RPU.parse_base_10('+99x') == {99, 'x'}
    assert RPU.parse_base_10('  -42 ') == {-42, ' '}
    assert RPU.parse_base_10('   xyz') == {0, 'xyz'}
  end

  test "parse_timezone_offset/1" do
    assert RPU.parse_timezone_offset('0') == {0, ''}
    assert RPU.parse_timezone_offset('') == {0, ''}
    assert RPU.parse_timezone_offset('-0315X') == {-195, 'X'}
    assert RPU.parse_timezone_offset('+0400abc') == {240, 'abc'}
  end
end
