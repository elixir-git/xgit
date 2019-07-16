# Copyright (C) 2006-2007, Shawn O. Pearce <spearce@spearce.org>
# and other copyright owners as documented in the project's IP log.
#
# Elixir adaptation from jgit file:
# org.eclipse.jgit.test/tst/org/eclipse/jgit/lib/T0001_PersonIdentTest.java
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

defmodule Xgit.Core.PersonIdentTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.PersonIdent

  describe "sanitized/1" do
    test "strips whitespace and non-parseable characters from raw string" do
      assert PersonIdent.sanitized(" Baz>\n\u1234<Quux ") == "Baz\u1234Quux"
    end
  end

  describe "format_timezone/1" do
    test "formats as +/-hhmm" do
      assert PersonIdent.format_timezone(-120) == "-0200"
      assert PersonIdent.format_timezone(-690) == "-1130"
      assert PersonIdent.format_timezone(0) == "+0000"
      assert PersonIdent.format_timezone(150) == "+0230"
    end
  end

  describe "to_external_string/1" do
    # We don't have support for named timezones yet. (Elixir 1.9?)
    # test "converts EST to numeric timezone" do
    #   pi = %PersonIdent{name: "A U Thor", email: "author@example.com", when: 1142878501000, tz_offset: "EST"}
    #   assert PersonIdent.to_external_string(pi) == "A U Thor <author@example.com> 1142878501 -0500"
    # end

    test "converts numeric timezone to +/-hhmm notation" do
      pi = %PersonIdent{
        name: "A U Thor",
        email: "author@example.com",
        when: 1_142_878_501_000,
        tz_offset: 150
      }

      assert PersonIdent.to_external_string(pi) ==
               "A U Thor <author@example.com> 1142878501 +0230"
    end

    test "trims all whitespace" do
      pi = %PersonIdent{
        name: "  \u0001 \n ",
        email: "  \u0001 \n ",
        when: 1_142_878_501_000,
        tz_offset: 0
      }

      assert PersonIdent.to_external_string(pi) == " <> 1142878501 +0000"
    end

    test "trims other bad characters" do
      pi = %PersonIdent{
        name: " Foo\r\n<Bar> ",
        email: " Baz>\n\u1234<Quux ",
        when: 1_142_878_501_000,
        tz_offset: 0
      }

      assert PersonIdent.to_external_string(pi) == "Foo\rBar <Baz\u1234Quux> 1142878501 +0000"
    end

    test "handles empty name and email" do
      pi = %PersonIdent{name: "", email: "", when: 1_142_878_501_000, tz_offset: 0}
      assert PersonIdent.to_external_string(pi) == " <> 1142878501 +0000"
    end
  end

  describe "String.Chars.to_string/1" do
    # We don't have support for named timezones yet. (Elixir 1.9?)
    # test "converts EST to numeric timezone" do
    #   pi = %PersonIdent{name: "A U Thor", email: "author@example.com", when: 1142878501000, tz_offset: "EST"}
    #   assert to_string(pi) == "A U Thor <author@example.com> 1142878501 -0500"
    # end

    test "converts numeric timezone to +/-hhmm notation" do
      pi = %PersonIdent{
        name: "A U Thor",
        email: "author@example.com",
        when: 1_142_878_501_000,
        tz_offset: 150
      }

      assert to_string(pi) == "A U Thor <author@example.com> 1142878501 +0230"
    end

    test "trims all whitespace" do
      pi = %PersonIdent{
        name: "  \u0001 \n ",
        email: "  \u0001 \n ",
        when: 1_142_878_501_000,
        tz_offset: 0
      }

      assert to_string(pi) == " <> 1142878501 +0000"
    end

    test "trims other bad characters" do
      pi = %PersonIdent{
        name: " Foo\r\n<Bar> ",
        email: " Baz>\n\u1234<Quux ",
        when: 1_142_878_501_000,
        tz_offset: 0
      }

      assert to_string(pi) == "Foo\rBar <Baz\u1234Quux> 1142878501 +0000"
    end

    test "handles empty name and email" do
      pi = %PersonIdent{name: "", email: "", when: 1_142_878_501_000, tz_offset: 0}
      assert to_string(pi) == " <> 1142878501 +0000"
    end
  end
end
