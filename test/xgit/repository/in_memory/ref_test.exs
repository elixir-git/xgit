defmodule Xgit.Repository.InMemory.RefTest do
  # We test all of the Ref-related tests together.

  use ExUnit.Case, async: true

  alias Xgit.Core.Object
  alias Xgit.Core.Ref
  alias Xgit.Plumbing.HashObject
  alias Xgit.Repository
  alias Xgit.Repository.InMemory

  describe "ref APIs" do
    test "list_refs/1 null case" do
      {:ok, repo} = InMemory.start_link()
      assert {:ok, []} = Repository.list_refs(repo)
    end

    test "get_ref/2 not_found case" do
      {:ok, repo} = InMemory.start_link()
      assert {:error, :not_found} = Repository.get_ref(repo, "refs/heads/master")
    end

    test "get_ref/2 invalid_name case" do
      {:ok, repo} = InMemory.start_link()
      assert {:error, :invalid_name} = Repository.get_ref(repo, "refs/../../heads/master")
    end

    test "put_ref/2: error object must exist" do
      {:ok, repo} = InMemory.start_link()

      assert {:error, :target_not_found} =
               Repository.put_ref(repo, %Ref{
                 name: "refs/heads/master",
                 target: "532ad3cb2518ad13a91e717998a26a6028df0623"
               })
    end

    @test_content 'test content\n'
    @test_content_id "d670460b4b4aece5915caf5c68d12f560a9fe3e4"

    test "put_ref: object exists, but is not a commit" do
      {:ok, repo} = InMemory.start_link()

      object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
      :ok = Repository.put_loose_object(repo, object)

      assert {:error, :target_not_commit} =
               Repository.put_ref(repo, %Ref{
                 name: "refs/heads/master",
                 target: @test_content_id
               })
    end

    test "put_ref followed by list and get" do
      {:ok, repo} = InMemory.start_link()

      {:ok, commit_id_master} =
        HashObject.run('shhh... not really a commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref = %Ref{
        name: "refs/heads/master",
        target: commit_id_master
      }

      assert :ok = Repository.put_ref(repo, master_ref)

      assert {:ok, [^master_ref]} = Repository.list_refs(repo)

      {:ok, commit_id_other} =
        HashObject.run('shhh... another fake commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      other_ref = %Ref{
        name: "refs/heads/other",
        target: commit_id_other
      }

      assert :ok = Repository.put_ref(repo, other_ref)

      assert {:ok, ^master_ref} = Repository.get_ref(repo, "refs/heads/master")
      assert {:ok, ^other_ref} = Repository.get_ref(repo, "refs/heads/other")

      assert {:ok, [^master_ref, ^other_ref]} = Repository.list_refs(repo)
    end
  end
end
