defmodule Xgit.Core.Ref do
  @moduledoc ~S"""
  A reference is a struct that describes a mutable pointer to a commit or similar object.

  A reference is a key-value pair where the key is a name in a specific format
  (see [`git check-ref-format`](https://git-scm.com/docs/git-check-ref-format))
  and the value (`:target`) is either a SHA-1 hash or a reference to another reference key
  (i.e. `ref: (name-of-valid-ref)`).

  This structure contains the key-value pair and functions to validate both values.
  """

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.ObjectId

  @typedoc ~S"""
  This struct describes a single reference stored or about to be stored in a git
  repository.

  ## Struct Members

  * `:name`: the name of the reference (typically `refs/heads/master` or similar)
  * `:target`: the object ID currently marked by this reference or a symbolic link
    (`ref: refs/heads/master` or similar) to another reference
  """
  @type t :: %__MODULE__{
          name: String.t(),
          target: ObjectId.t() | String.t()
        }

  @enforce_keys [:name, :target]
  defstruct [:name, :target]

  @doc ~S"""
  Return `true` if the string describes a valid reference name.
  """
  @spec valid_name?(name :: any) :: boolean
  def valid_name?(name) when is_binary(name), do: valid_name?(name, false, false)
  def valid_name?(_), do: cover(false)

  @doc ~S"""
  Return `true` if the struct describes a valid reference.

  ## Options

  `allow_one_level?`: Set to `true` to disregard the rule requiring at least one `/`
  in name. (Similar to `--allow-onelevel` option.)

  `refspec?`: Set to `true` to allow a single `*` in the pattern. (Similar to
  `--refspec-pattern` option.)
  """
  @spec valid?(ref :: any, allow_one_level?: boolean) :: boolean
  def valid?(ref, opts \\ [])

  def valid?(%__MODULE__{name: name, target: target}, opts)
      when is_binary(name) and is_binary(target)
      when is_list(opts) do
    valid_name?(
      name,
      Keyword.get(opts, :allow_one_level?, false),
      Keyword.get(opts, :refspec?, false)
    ) && valid_target?(target)
  end

  def valid?(_, _opts), do: cover(false)

  defp valid_name?("@", _, _), do: cover(false)

  defp valid_name?(name, true, false) do
    all_components_valid?(name) && not Regex.match?(~r/[\x00-\x20\\\?\[:^\x7E\x7F]/, name) &&
      not String.ends_with?(name, ".") && not String.contains?(name, "@{")
  end

  defp valid_name?(name, false, false) do
    String.contains?(name, "/") && valid_name?(name, true, false) &&
      not String.contains?(name, "*")
  end

  defp valid_name?(name, false, true) do
    String.contains?(name, "/") && valid_name?(name, true, false) && at_most_one_asterisk?(name)
  end

  defp all_components_valid?(name) do
    name
    |> String.split("/")
    |> Enum.all?(&name_component_valid?/1)
  end

  defp name_component_valid?(component), do: not name_component_invalid?(component)

  defp name_component_invalid?(""), do: cover(true)

  defp name_component_invalid?(component) do
    String.starts_with?(component, ".") ||
      String.ends_with?(component, ".lock") ||
      String.contains?(component, "..")
  end

  @asterisk_re ~r/\*/

  defp at_most_one_asterisk?(name) do
    @asterisk_re
    |> Regex.scan(name)
    |> Enum.count()
    |> Kernel.<=(1)
  end

  defp valid_target?(target), do: ObjectId.valid?(target) || valid_ref_target?(target)

  defp valid_ref_target?("ref: " <> target_name),
    do: valid_name?(target_name, false, false) && String.starts_with?(target_name, "refs/")

  defp valid_ref_target?(_), do: cover(false)
end
