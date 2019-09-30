defmodule Xgit.Core.CommitTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Commit
  alias Xgit.Core.PersonIdent

  @invalid_pi %PersonIdent{
    name: :bogus,
    email: "author@example.com",
    when: 1_142_878_501_000,
    tz_offset: 150
  }

  describe "valid?/1" do
    test "valid: no parent" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "valid: blank author" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("<> 0 +0000"),
               committer: pi("<> 0 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt author 1" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: @invalid_pi,
               committer: pi("<> 0 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt author 2" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: "A. U. Thor <author@localhost> 1 +0000",
               committer: pi("<> 0 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt committer 1" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("<> 0 +0000"),
               committer: @invalid_pi,
               message: 'x'
             })
    end

    test "invalid: corrupt committer 2" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("<> 0 +0000"),
               committer: "A. U. Thor <author@localhost> 1 +0000",
               message: 'x'
             })
    end

    test "valid: one parent" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ["be9bfa841874ccc9f2ef7c48d0c76226f89b7189"],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "valid: two parents" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: [
                 "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                 "be9bfa841874ccc9f2ef7c48d0c76226f89b7189"
               ],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "valid: 128 parents" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: Enum.map(1..128, fn _ -> "be9bfa841874ccc9f2ef7c48d0c76226f89b7189" end),
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "valid: normal time" do
      assert Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("A. U. Thor <author@localhost> 1222757360 -0730"),
               committer: pi("A. U. Thor <author@localhost> 1222757360 -0730"),
               message: 'x'
             })
    end

    test "invalid: invalid tree 1" do
      refute Commit.valid?(%Commit{
               tree: 'be9bfa841874ccc9f2ef7c48d0c76226f89b7189',
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid tree 2" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b718",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid tree 3" do
      refute Commit.valid?(%Commit{
               tree: "zzz9bfa841874ccc9f2ef7c48d0c76226f89b718",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid parent 1" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ["e9bfa841874ccc9f2ef7c48d0c76226f89b7189"],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid parent 2" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ['be9bfa841874ccc9f2ef7c48d0c76226f89b7189'],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid parent 3" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ["ze9bfa841874ccc9f2ef7c48d0c76226f89b7189"],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: invalid parent 4" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               parents: ["Be9bfa841874ccc9f2ef7c48d0c76226f89b7189"],
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: no message" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: ''
             })
    end

    test "invalid: message is string" do
      refute Commit.valid?(%Commit{
               tree: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               author: pi("A. U. Thor <author@localhost> 1 +0000"),
               committer: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: "x"
             })
    end

    defp pi(s) do
      s
      |> String.to_charlist()
      |> PersonIdent.from_byte_list()
    end
  end
end
