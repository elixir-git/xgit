defmodule Xgit.Util.ForceCoverage do
  @moduledoc false

  # This module is intended for internal testing purposes only.
  # We use it to wrap literal returns from functions in a way that
  # makes them visible to code coverage tools.

  # When building dev or production releases, we use a more efficient
  # form; when building for test (i.e. coverage), we use a more
  # complicated form that defeats compiler inlining.

  # Inspired by discussion at
  # https://elixirforum.com/t/functions-returning-a-literal-are-not-seen-by-code-coverage/16812.

  # coveralls-ignore-start

  if System.get_env("XGIT_FORCE_COVERAGE") do
    defmacro cover(false = x) do
      quote do
        inspect(unquote(x))
        unquote(x)
      end
    end

    defmacro cover(nil = x) do
      quote do
        inspect(unquote(x))
        unquote(x)
      end
    end

    defmacro cover(value) do
      quote do
        # credo:disable-for-next-line Credo.Check.Warning.BoolOperationOnSameValues
        false or unquote(value)
      end
    end
  else
    defmacro cover(value) do
      quote do
        unquote(value)
      end
    end
  end

  # coveralls-ignore-stop
end
