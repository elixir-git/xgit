defmodule Xgit.Util.SharedTestCase do
  @moduledoc false
  # Code to encourage sharing of test cases.
  # Adapted from https://blog.codeminer42.com/how-to-test-shared-behavior-in-elixir-3ea3ebb92b64/.

  defmacro define_shared_tests(do: block) do
    quote do
      defmacro __using__(options) do
        block = unquote(Macro.escape(block))

        async? = Keyword.get(options, :async, false)
        options_without_async = Keyword.delete(options, :async)

        quote do
          use ExUnit.Case, async: unquote(async?)

          @moduletag unquote(options_without_async)
          unquote(block)
        end
      end
    end
  end
end
