defmodule Xgit.TagTest do
  use ExUnit.Case, async: true

  # alias Xgit.GitInitTestCase
  # alias Xgit.Object
  alias Xgit.PersonIdent
  alias Xgit.Tag

  @invalid_pi %PersonIdent{
    name: :bogus,
    email: "author@example.com",
    when: 1_142_878_501_000,
    tz_offset: 150
  }

  describe "valid?/1" do
    test "valid" do
      assert Tag.valid?(%Tag{
               object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               type: :commit,
               name: 'test',
               tagger: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt object ID" do
      refute Tag.valid?(%Tag{
               object: "be9bfa841874ccc9f2ef7c48d0c76226f89b718",
               type: :commit,
               name: 'test',
               tagger: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt type 1" do
      refute Tag.valid?(%Tag{
               object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               type: "commit",
               name: 'test',
               tagger: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt type 2" do
      refute Tag.valid?(%Tag{
               object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               type: :commit?,
               name: 'test',
               tagger: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "invalid: empty name" do
      refute Tag.valid?(%Tag{
               object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               type: :commit,
               name: '',
               tagger: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: 'x'
             })
    end

    test "valid: blank tagger" do
      assert Tag.valid?(%Tag{
               object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               type: :commit,
               name: 'test',
               tagger: pi("<> 0 +0000"),
               message: 'x'
             })
    end

    test "invalid: corrupt tagger 1" do
      refute Tag.valid?(%Tag{
               object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               type: :commit,
               name: 'test',
               tagger: @invalid_pi,
               message: 'x'
             })
    end

    test "invalid: corrupt tagger 2" do
      refute Tag.valid?(%Tag{
               object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               type: :commit,
               name: 'test',
               tagger: "A. U. Thor <author@localhost> 1 +0000",
               message: 'x'
             })
    end

    test "invalid: empty message" do
      refute Tag.valid?(%Tag{
               object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
               type: :commit,
               name: 'test',
               tagger: pi("A. U. Thor <author@localhost> 1 +0000"),
               message: ''
             })
    end

    defp pi(s) do
      s
      |> String.to_charlist()
      |> PersonIdent.from_byte_list()
    end
  end
end
