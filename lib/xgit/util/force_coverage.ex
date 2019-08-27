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

  if Application.get_env(:xgit, :use_force_coverage?) do
    defmacro return(value) do
      quote do
        x = unquote(value)

        if is_boolean(x) do
          x or x
        else
          false or x
        end
      end
    end
  else
    defmacro return(value) do
      quote do
        unquote(value)
      end
    end
  end
end
