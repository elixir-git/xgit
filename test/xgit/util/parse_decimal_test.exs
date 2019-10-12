defmodule Xgit.Util.ParseDecimalTest do
  use ExUnit.Case, async: true

  import Xgit.Util.ParseDecimal

  test "from_decimal_charlist/1" do
    assert from_decimal_charlist('abc') == {0, 'abc'}
    assert from_decimal_charlist('0abc') == {0, 'abc'}
    assert from_decimal_charlist('99') == {99, ''}
    assert from_decimal_charlist('+99x') == {99, 'x'}
    assert from_decimal_charlist('  -42 ') == {-42, ' '}
    assert from_decimal_charlist('   xyz') == {0, 'xyz'}
  end
end
