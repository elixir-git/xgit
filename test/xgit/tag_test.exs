defmodule Xgit.TagTest do
  use ExUnit.Case, async: true

  alias Xgit.Object
  alias Xgit.PersonIdent
  alias Xgit.Repository.Storage
  alias Xgit.Tag
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  @valid_pi %PersonIdent{
    name: "A. U. Thor",
    email: "author@example.com",
    when: 1_142_878_501_000,
    tz_offset: 150
  }

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

    test "invalid: invalid type" do
      assert {:error, :invalid_tag} =
               Tag.from_object(%Object{
                 type: :tag,
                 content: ~c"""
                 object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
                 type bogus
                 tag test-tag
                 tagger A. U. Thor <author@localhost> 1 +0000
                 """
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

  describe "to_object/1" do
    test "happy path: typical tag" do
      assert_same_output(
        fn git_dir, commit_id, env ->
          System.cmd("git", ["tag", "-a", "test_tag", commit_id, "-m", "x"], cd: git_dir, env: env)
        end,
        fn commit_id ->
          %Tag{
            object: commit_id,
            type: :commit,
            name: 'test_tag',
            tagger: @valid_pi,
            message: 'x\n'
          }
        end
      )
    end

    test "raises FunctionClauseError if tagger is empty" do
      assert_raise FunctionClauseError, fn ->
        Tag.to_object(%Tag{
          object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
          type: :commit,
          name: 'test_tag',
          tagger: nil,
          message: 'x\n'
        })
      end
    end

    test "raises ArgumentError if tag is invalid" do
      assert_raise ArgumentError, "Xgit.Tag.to_object/1: tag is not valid", fn ->
        Tag.to_object(%Tag{
          object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
          type: :commit,
          name: '',
          tagger: @valid_pi,
          message: 'x\n'
        })
      end
    end

    defp assert_same_output(write_tag_fn, xgit_fn, opts \\ []) do
      tagger_date = Keyword.get(opts, :tagger_date, "1142878501 +0230")
      tagger_name = Keyword.get(opts, :tagger_name, "A. U. Thor")
      tagger_email = Keyword.get(opts, :tagger_email, "author@example.com")

      %{xgit_path: ref, parent_id: ref_commit_id} =
        OnDiskRepoTestCase.setup_with_valid_parent_commit!()

      %{xgit_path: xgit, xgit_repo: repo, parent_id: xgit_commit_id} =
        OnDiskRepoTestCase.setup_with_valid_parent_commit!()

      env = [
        {"GIT_AUTHOR_DATE", tagger_date},
        {"GIT_COMMITTER_DATE", tagger_date},
        {"GIT_AUTHOR_EMAIL", tagger_email},
        {"GIT_COMMITTER_EMAIL", tagger_email},
        {"GIT_AUTHOR_NAME", tagger_name},
        {"GIT_COMMITTER_NAME", tagger_name}
      ]

      write_tag_fn.(ref, ref_commit_id, env)

      xgit_tag_object =
        xgit_commit_id
        |> xgit_fn.()
        |> Tag.to_object()

      assert Object.valid?(xgit_tag_object)
      assert :ok = Object.check(xgit_tag_object)

      # assert xgit_tag_object.id == ref_tag_id
      # TO DO: How to verify when c/l git doesn't give us that ID?

      :ok = Storage.put_loose_object(repo, xgit_tag_object)

      assert_folders_are_equal(
        Path.join([ref, ".git", "objects"]),
        Path.join([xgit, ".git", "objects"])
      )
    end
  end
end
