defmodule Xgit.Util.ParseCharlistTest do
  use ExUnit.Case, async: true

  alias Xgit.Util.ParseCharlist

  test "decode/1" do
    assert ParseCharlist.decode_ambiguous_charlist([64, 65, 66]) == "@AB"
    assert ParseCharlist.decode_ambiguous_charlist([228, 105, 116, 105]) == "äiti"
    assert ParseCharlist.decode_ambiguous_charlist([195, 164, 105, 116, 105]) == "äiti"
    assert ParseCharlist.decode_ambiguous_charlist([66, 106, 246, 114, 110]) == "Björn"
    assert ParseCharlist.decode_ambiguous_charlist([66, 106, 195, 182, 114, 110]) == "Björn"
  end
end
