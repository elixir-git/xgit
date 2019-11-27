defmodule Xgit.Core.RefTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Ref

  defp assert_valid_name(name, opts \\ []) do
    unless name == "HEAD" do
      assert {_, 0} = System.cmd("git", check_ref_format_args(name, opts))
    end

    assert Ref.valid?(%Ref{name: name, target: "155b7b4b7a6b798725df04a6cfcfb1aa042f0834"}, opts)

    if Enum.empty?(opts) && String.starts_with?(name, "refs/") do
      assert Ref.valid?(%Ref{name: "refs/heads/master", target: "ref: #{name}"}, opts)
      assert Ref.valid_name?(name)
    end
  end

  defp refute_valid_name(name, opts \\ []) do
    assert {_, 1} = System.cmd("git", check_ref_format_args(name, opts))
    refute Ref.valid?(%Ref{name: name, target: "155b7b4b7a6b798725df04a6cfcfb1aa042f0834"}, opts)

    if Enum.empty?(opts) && String.starts_with?(name, "refs/") do
      refute Ref.valid?(%Ref{name: "refs/heads/master", target: "ref: #{name}"}, opts)
      refute Ref.valid_name?(name)
    end
  end

  defp check_ref_format_args(name, opts) do
    ["check-ref-format"]
    |> maybe_add_allow_one_level(Keyword.get(opts, :allow_one_level?, false))
    |> maybe_add_refspec(Keyword.get(opts, :refspec?, false))
    |> Kernel.++([name])
  end

  defp maybe_add_allow_one_level(args, false), do: args
  defp maybe_add_allow_one_level(args, true), do: args ++ ["--allow-onelevel"]

  defp maybe_add_refspec(args, false), do: args
  defp maybe_add_refspec(args, true), do: args ++ ["--refspec-pattern"]

  describe "valid?/1 name" do
    # From documentation for git check-ref-format
    # (https://git-scm.com/docs/git-check-ref-format):

    test "HEAD" do
      assert_valid_name("HEAD")
      refute_valid_name("HEADx")
    end

    # "Git imposes the following rules on how references are named:"

    test "can include slash / for hierarchical (directory) grouping" do
      assert_valid_name("refs/heads")
      assert_valid_name("refs/heads/master")
      assert_valid_name("refs/heads/group/subgroup")
    end

    test "no slash-separated component can begin with a dot . or end with the sequence .lock." do
      refute_valid_name(".refs/heads")
      refute_valid_name("refs/.heads/master")
      refute_valid_name("refs/heads/.master")
      refute_valid_name("refs.lock/heads")
      refute_valid_name("refs/heads.lock")
      assert_valid_name("refs.lockx/heads")
      assert_valid_name("refs/heads_lock")
    end

    test "must contain at least one /" do
      # This enforces the presence of a category like heads/, tags/ etc.
      # but the actual names are not restricted.
      assert_valid_name("refs/heads")
      assert_valid_name("refs/heads/master")
      refute_valid_name("refs")
      refute_valid_name("")
    end

    test "if the --allow-onelevel option is used, this rule is waived" do
      assert_valid_name("refs/heads", allow_one_level?: true)
      assert_valid_name("refs/heads/master", allow_one_level?: true)
      assert_valid_name("refs", allow_one_level?: true)
      refute_valid_name("", allow_one_level?: true)
      # Empty name is still disallowed.
    end

    test "cannot have two consecutive dots .. anywhere" do
      assert_valid_name("refs/he.ds")
      refute_valid_name("refs/he..ds")
      refute_valid_name("refs/../blah")
      refute_valid_name("refs../heads")
    end

    test "cannot have ASCII control characters" do
      # (i.e. bytes whose values are lower than \040, or \177 DEL), space, tilde ~, caret ^,
      # or colon : anywhere.
      refute_valid_name("refs/he\u001fads")
      refute_valid_name("refs/he\u007fads")
      refute_valid_name("refs/he ads")
      refute_valid_name("refs/~heads")
      refute_valid_name("refs/^heads")
      refute_valid_name("refs/he:ads")
    end

    test "cannot have question-mark ?, asterisk *, or open bracket [ anywhere" do
      refute_valid_name("refs/he?ads")
      refute_valid_name("refs/heads?")
      refute_valid_name("refs/heads/*")
      refute_valid_name("refs/heads*/foo")
      refute_valid_name("refs/heads/[foo")
      refute_valid_name("refs/hea[ds/foo")
    end

    test "allows a single asterisk * with --refspec-pattern" do
      # See the --refspec-pattern option below for an exception to this rule.
      refute_valid_name("refs/heads/*")
      assert_valid_name("refs/heads/*", refspec?: true)
      refute_valid_name("refs/heads*/foo")
      assert_valid_name("refs/heads*/foo", refspec?: true)
    end

    test "cannot begin or end with a slash / or contain multiple consecutive slashes" do
      refute_valid_name("/refs/heads/foo")
      refute_valid_name("refs/heads/master/")
      refute_valid_name("refs//heads/master")
    end

    test "cannot end with a dot ." do
      assert_valid_name("refs./heads/master")
      refute_valid_name("refs/heads/master.")
    end

    test "cannot contain a sequence @{" do
      assert_valid_name("refs/heads/@master")
      assert_valid_name("refs/heads/{master")
      refute_valid_name("refs/heads/@{master")
    end

    test "cannot be the single character @" do
      assert_valid_name("refs/@/master")
      refute_valid_name("@")
      refute_valid_name("@", allow_one_level?: true)
    end

    test "cannot contain a \\" do
      refute_valid_name("refs\\heads/master")
    end
  end

  describe "valid?/1 target" do
    defp assert_valid_target(target) do
      assert Ref.valid?(%Ref{name: "refs/heads/master", target: target})
    end

    defp refute_valid_target(target) do
      refute Ref.valid?(%Ref{name: "refs/heads/master", target: target})
    end

    test "object ID" do
      assert_valid_target("1234567890abcdef12341234567890abcdef1234")
      refute_valid_target("1234567890abcdef1231234567890abcdef1234")
      refute_valid_target("1234567890abcdef123451234567890abcdef1234")
      refute_valid_target("1234567890abCdef12341234567890abcdef1234")
      refute_valid_target("1234567890abXdef12341234567890abcdef1234")

      refute_valid_target(nil)
    end

    test "ref" do
      assert_valid_target("ref: refs/heads/master")
      refute_valid_target("ref:")
      refute_valid_target("rex: refs/heads/master")
      refute_valid_target("ref: refs")
    end

    test "ref must point inside of refs/ hierarchy" do
      refute_valid_target("ref: refsxyz/heads/master")
      refute_valid_target("ref: rex/heads/master")
    end
  end

  describe "valid?/1 link_target" do
    defp assert_valid_link_target(link_target) do
      assert Ref.valid?(%Ref{
               name: "refs/heads/master",
               target: "fd1ca70f4d329c6ee9e47f3bbef65a3884236f08",
               link_target: link_target
             })
    end

    defp refute_valid_link_target(link_target) do
      refute Ref.valid?(%Ref{
               name: "refs/heads/master",
               target: "fd1ca70f4d329c6ee9e47f3bbef65a3884236f08",
               link_target: link_target
             })
    end

    test "object ID" do
      refute_valid_link_target("1234567890abcdef12341234567890abcdef1234")
    end

    test "nil" do
      assert_valid_link_target(nil)
    end

    test "valid ref name" do
      assert_valid_link_target("refs/heads/master")
      refute_valid_link_target("")
      refute_valid_link_target("refs")
    end

    test "ref must point inside of refs/ hierarchy" do
      refute_valid_link_target("refsxyz/heads/master")
      refute_valid_link_target("rex/heads/master")
    end
  end

  test "valid?/1 not a Ref" do
    refute Ref.valid?("refs/heads/master")
    refute Ref.valid?(42)
    refute Ref.valid?(nil)

    refute Ref.valid?(%{
             name: "refs/heads/master",
             target: "155b7b4b7a6b798725df04a6cfcfb1aa042f0834"
           })
  end

  test "valid_name?/1 not a string" do
    refute Ref.valid_name?('refs/heads/master')
    refute Ref.valid_name?(42)
    refute Ref.valid_name?(nil)
  end
end
