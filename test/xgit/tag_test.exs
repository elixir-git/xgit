defmodule Xgit.TagTest do
  use ExUnit.Case, async: true

  alias Xgit.Object
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

  describe "from_object/1" do
    test "valid: has message" do
      assert {:ok,
              %Tag{
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'test-tag',
                tagger: %Xgit.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: 0,
                  when: 1
                },
                message: 'test message\n'
              }} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tag test-tag
                 tagger A. U. Thor <author@localhost> 1 +0000

                 test message
                 """
               })
    end

    test "valid: empty message" do
      assert {:ok,
              %Tag{
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'test-tag',
                tagger: %Xgit.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: 0,
                  when: 1
                },
                message: ''
              }} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tag test-tag
                 tagger A. U. Thor <author@localhost> 1 +0000
                 """
               })
    end

    test "invalid: no object 1" do
      assert {:error, :invalid_tag} = Tag.from_object(%Object{type: :tag, content: []})
    end

    test "invalid: no object 2" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: 'object\tbe9bfa841874ccc9f2ef7c48d0c76226f89b7189\n'
               })
    end

    test "invalid: no object 3" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 obejct be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no object 4" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object zz9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no object 5" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: 'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189 \n'
               })
    end

    test "invalid: no object 6" do
      assert {:error, :invalid_tag} = Tag.from_object(%Object{type: :tag, content: 'object be9'})
    end

    test "invalid: no type 1" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 """
               })
    end

    test "invalid: no type 2" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content:
                   'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'type\tcommit\n'
               })
    end

    test "invalid: no type 3" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 tpye commit
                 """
               })
    end

    test "invalid: no type 4" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content:
                   'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'type commit'
               })
    end

    test "invalid: no tag header 1" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 """
               })
    end

    test "invalid: no tag header 2" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content:
                   'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'type commit\n' ++
                     'tag\tfoo\n'
               })
    end

    test "invalid: no tag header 3" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tga foo
                 """
               })
    end

    test "valid: has no tagger header" do
      assert {:ok,
              %Xgit.Tag{
                message: [],
                name: 'foo',
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                tagger: nil,
                type: :commit
              }} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tag foo
                 """
               })
    end

    test "invalid: invalid tagger header 1" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content:
                   'object be9bfa841874ccc9f2ef7c48d0c76226f89b7189\n' ++
                     'type commit\n' ++
                     'tag foo\n' ++
                     'tagger \n'
               })
    end

    test "invalid: invalid tagger header 3" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tag foo
                 tagger a < 1 +000
                 """
               })
    end

    test "invalid: has message without separator" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type commit
                 tag test-tag
                 tagger A. U. Thor <author@localhost> 1 +0000
                 test message (should have blank line before this)
                 """
               })
    end

    test "object is not a tag" do
      object = %Object{
        type: :blob,
        content: 'test content\n',
        size: 13,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
      }

      assert {:error, :not_a_tag} = Tag.from_object(object)
    end
  end
end
