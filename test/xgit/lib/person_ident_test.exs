defmodule Xgit.Lib.PersonIdentTest do
  use ExUnit.Case

  alias Xgit.Lib.PersonIdent
  doctest Xgit.Lib.PersonIdent

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
end
