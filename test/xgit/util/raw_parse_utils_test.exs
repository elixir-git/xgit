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

  @commit 'tree e3a1035abd2b319bb01e57d69b0ba6cab289297e\n' ++
            'parent 54e895b87c0768d2317a2b17062e3ad9f76a8105\n' ++
            'committer A U Thor <author@xample.com 1528968566 +0200\n' ++
            'gpgsig -----BEGIN PGP SIGNATURE-----\n' ++
            ' \n' ++
            ' wsBcBAABCAAQBQJbGB4pCRBK7hj4Ov3rIwAAdHIIAENrvz23867ZgqrmyPemBEZP\n' ++
            ' U24B1Tlq/DWvce2buaxmbNQngKZ0pv2s8VMc11916WfTIC9EKvioatmpjduWvhqj\n' ++
            ' znQTFyiMor30pyYsfrqFuQZvqBW01o8GEWqLg8zjf9Rf0R3LlOEw86aT8CdHRlm6\n' ++
            ' wlb22xb8qoX4RB+LYfz7MhK5F+yLOPXZdJnAVbuyoMGRnDpwdzjL5Hj671+XJxN5\n' ++
            ' SasRdhxkkfw/ZnHxaKEc4juMz8Nziz27elRwhOQqlTYoXNJnsV//wy5Losd7aKi1\n' ++
            ' xXXyUpndEOmT0CIcKHrN/kbYoVL28OJaxoBuva3WYQaRrzEe3X02NMxZe9gkSqA=\n' ++
            ' =TClh\n' ++
            ' -----END PGP SIGNATURE-----\n' ++
            'some other header\n\n' ++
            'commit message'

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

  test "next/2" do
    assert RPU.next('abcddef', ?d) == 'def'
    assert RPU.next('abcd', ?d) == ''
    assert RPU.next('abcd', ?x) == ''
  end

  test "next_lf/1" do
    assert RPU.next_lf('abc\ndef') == 'def'
    assert RPU.next_lf('xyz') == ''
  end

  test "next_lf/2" do
    assert RPU.next_lf('abc\ndef', ?c) == 'c\ndef'
    assert RPU.next_lf('abc\ndef', ?d) == '\ndef'
    assert RPU.next_lf('xyz', ?y) == 'yz'
  end

  test "decode/1" do
    assert RPU.decode([64, 65, 66]) == "@AB"
    assert RPU.decode([228, 105, 116, 105]) == "äiti"
    assert RPU.decode([195, 164, 105, 116, 105]) == "äiti"
    assert RPU.decode([66, 106, 246, 114, 110]) == "Björn"
    assert RPU.decode([66, 106, 195, 182, 114, 110]) == "Björn"
  end
end
