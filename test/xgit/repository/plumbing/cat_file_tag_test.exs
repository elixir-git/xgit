defmodule Xgit.Repository.Plumbing.CatFileTagTest do
  use Xgit.Test.OnDiskRepoTestCase, async: true

  alias Xgit.PersonIdent
  alias Xgit.Repository.InMemory
  alias Xgit.Repository.InvalidRepositoryError
  alias Xgit.Repository.Plumbing
  alias Xgit.Tag
  alias Xgit.Test.OnDiskRepoTestCase

  @env OnDiskRepoTestCase.sample_commit_env()

  import Xgit.Test.OnDiskRepoTestCase

  describe "cat_file_tag/2" do
    test "command-line interop: basic case" do
      %{xgit_path: path, xgit_repo: repo, tree_id: tree_id} = setup_with_valid_tree!()

      assert {commit_id_str, 0} =
               System.cmd("git", ["commit-tree", tree_id, "-m", "xxx"], cd: path, env: @env)

      commit_id = String.trim(commit_id_str)

      assert {"", 0} =
               System.cmd("git", ["tag", "-a", "blah", commit_id, "-m", "test tag"],
                 cd: path,
                 env: @env
               )

      tag_id_str = File.read!(Path.join([path, ".git", "refs", "tags", "blah"]))

      tag_id = String.trim(tag_id_str)

      assert {:ok,
              %Tag{
                object: ^commit_id,
                type: :commit,
                name: 'blah',
                tagger: %PersonIdent{
                  email: "author@example.com",
                  name: "A. U. Thor",
                  tz_offset: 150,
                  when: 1_142_878_449
                },
                message: 'test tag\n'
              }} = Plumbing.cat_file_tag(repo, tag_id)
    end

    defp write_tag_and_cat_file!(tag_text) do
      %{xgit_repo: xgit_repo} = repo!()

      {:ok, tag_id} =
        Plumbing.hash_object(tag_text,
          repo: xgit_repo,
          type: :tag,
          validate?: false,
          write?: true
        )

      Plumbing.cat_file_tag(xgit_repo, tag_id)
    end

    test "valid: no message" do
      assert {:ok,
              %Xgit.Tag{
                tagger: %Xgit.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: 0,
                  when: 1
                },
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'tag_name',
                message: ''
              }} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "valid: no tagger" do
      assert {:ok,
              %Xgit.Tag{
                tagger: nil,
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'tag_name',
                message: 'foo\n'
              }} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name

               foo
               """)
    end

    test "invalid: unknown headers" do
      # TO DO: Support signatures and other extensions.
      # https://github.com/elixir-git/xgit/issues/202

      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger A. U. Thor <author@localhost> 1 +0000
               abc
               def
               """)
    end

    test "valid: blank tagger" do
      assert {:ok,
              %Xgit.Tag{
                tagger: %Xgit.PersonIdent{
                  email: "",
                  name: "",
                  tz_offset: 0,
                  when: 0
                },
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'tag_name',
                message: ''
              }} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger <> 0 +0000
               """)
    end

    test "invalid: corrupt tagger" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger 0 +0000
               """)
    end

    test "valid: normal time" do
      assert {:ok,
              %Xgit.Tag{
                tagger: %Xgit.PersonIdent{
                  email: "author@localhost",
                  name: "A. U. Thor",
                  tz_offset: -450,
                  when: 1_222_757_360
                },
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'tag_name',
                message: ''
              }} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger A. U. Thor <author@localhost> 1222757360 -0730
               """)
    end

    test "invalid: no object" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               type commit
               tag tag_name
               tagger A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "invalid: invalid object 1" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b718
               type commit
               tag tag_name
               tagger A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "invalid: invalid object 2" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               objectbe9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "invalid: invalid object 3" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               object\tbe9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "invalid: invalid object 4" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               object be9b
               """)
    end

    test "invalid: invalid object 5" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               object  be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               """)
    end

    test "invalid: no type" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               tag tag_name
               tagger A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "invalid: unknown type" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type bogus
               tag tag_name
               tagger A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "invalid: missing tag name 1" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~c"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tagger A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "invalid: missing tag name 2" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~c"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag
               tagger A. U. Thor <author@localhost> 1 +0000
               """)
    end

    test "valid: no tagger and no message" do
      assert {:ok,
              %Xgit.Tag{
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'tag_name',
                tagger: nil,
                message: []
              }} =
               write_tag_and_cat_file!(~c"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               """)
    end

    test "invalid: invalid tagger 1" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~C"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger A. U. Thor <foo 1 +0000
               """)
    end

    test "invalid: invalid tagger 2" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~c"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger A. U. Thor foo> 1 +0000
               """)
    end

    test "invalid: invalid tagger 3" do
      assert {:error, :invalid_tag} =
               write_tag_and_cat_file!(~c"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger 1 +0000
               """)
    end

    # Re: "fuzzy, but accepted," see PersonIdent.from_bytelist/1.
    # There, we followed jgit's lead and decided to accept "lots of junk"
    # after the email address. The following examples are technically
    # incorrect, but can at least be parsed far enough that it's not worth
    # being pedantic about the errors.

    test "fuzzy, but accepted: invalid tagger 4" do
      assert {:ok,
              %Xgit.Tag{
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'tag_name',
                tagger: %Xgit.PersonIdent{
                  email: "b",
                  name: "a",
                  tz_offset: 0,
                  when: 0
                },
                message: []
              }} =
               write_tag_and_cat_file!(~c"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger a <b> x +0000
               """)
    end

    test "fuzzy but accepted: invalid tagger 5" do
      assert {:ok,
              %Xgit.Tag{
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'tag_name',
                tagger: %Xgit.PersonIdent{
                  email: "b",
                  name: "a",
                  tz_offset: 0,
                  when: 0
                },
                message: []
              }} =
               write_tag_and_cat_file!(~c"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger a <b>
               """)
    end

    test "fuzzy, but accepted: invalid tagger 6" do
      assert {:ok,
              %Xgit.Tag{
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'tag_name',
                tagger: %Xgit.PersonIdent{
                  email: "b",
                  name: "a",
                  tz_offset: 0,
                  when: 0
                },
                message: []
              }} =
               write_tag_and_cat_file!(~c"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger a <b> z
               """)
    end

    test "fuzzy, but accepted: invalid tagger 7" do
      assert {:ok,
              %Xgit.Tag{
                object: "be9bfa841874ccc9f2ef7c48d0c76226f89b7189",
                type: :commit,
                name: 'tag_name',
                tagger: %Xgit.PersonIdent{
                  email: "b",
                  name: "a",
                  tz_offset: 0,
                  when: 1
                },
                message: []
              }} =
               write_tag_and_cat_file!(~c"""
               object be9bfa841874ccc9f2ef7c48d0c76226f89b7189
               type commit
               tag tag_name
               tagger a <b> 1 z
               """)
    end

    test "error: not_found" do
      {:ok, repo} = InMemory.start_link()

      assert {:error, :not_found} =
               Plumbing.cat_file_tag(repo, "6c22d81cc51c6518e4625a9fe26725af52403b4f")
    end

    test "error: invalid_object", %{xgit_repo: xgit_repo, xgit_path: xgit_path} do
      path = Path.join([xgit_path, ".git", "objects", "5c"])
      File.mkdir_p!(path)

      File.write!(
        Path.join(path, "b5d77be2d92c7368038dac67e648a69e0a654d"),
        <<120, 1, 75, 202, 201, 79, 170, 80, 48, 52, 50, 54, 97, 0, 0, 22, 54, 3, 2>>
      )

      assert {:error, :invalid_object} =
               Plumbing.cat_file_tag(xgit_repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
    end

    test "error: not_a_commit", %{xgit_repo: xgit_repo, xgit_path: xgit_path} do
      Temp.track!()
      path = Temp.path!()

      File.write!(path, "test content\n")

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: xgit_path)
      object_id = String.trim(output)

      assert {:error, :not_a_tag} = Plumbing.cat_file_tag(xgit_repo, object_id)
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        Plumbing.cat_file_tag("xgit repo", "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        Plumbing.cat_file_tag(not_repo, "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
      end
    end

    test "error: object_id invalid (not binary)" do
      {:ok, repo} = InMemory.start_link()

      assert_raise FunctionClauseError, fn ->
        Plumbing.cat_file_tag(repo, 0x18A4)
      end
    end

    test "error: object_id invalid (binary, but not valid object ID)" do
      {:ok, repo} = InMemory.start_link()

      assert {:error, :invalid_object_id} =
               Plumbing.cat_file_tag(repo, "some random ID that isn't valid")
    end
  end
end
