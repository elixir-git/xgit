defmodule Xgit.Repository.InMemory.RefTest do
  # We test all of the Ref-related tests together.

  use ExUnit.Case, async: true

  alias Xgit.Core.Object
  alias Xgit.Core.Ref
  alias Xgit.Plumbing.HashObject
  alias Xgit.Repository
  alias Xgit.Repository.InMemory

  describe "ref APIs" do
    test "default repo contains HEAD reference" do
      {:ok, repo} = InMemory.start_link()

      assert {:ok, %Xgit.Core.Ref{name: "HEAD", target: "ref: refs/heads/master"}} =
               Repository.get_ref(repo, "HEAD")
    end

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

    test "put_ref/3: invalid reference" do
      {:ok, repo} = InMemory.start_link()

      assert {:error, :invalid_ref} =
               Repository.put_ref(repo, %Ref{
                 name: "refs/heads/master",
                 target: "532ad3cb2518ad13a91e717998a26a6028df062"
               })
    end

    test "put_ref/3: error object must exist" do
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

    test "put_ref: :old_target (correct match)" do
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

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref2 = %Ref{
        name: "refs/heads/master",
        target: commit_id2_master
      }

      assert :ok = Repository.put_ref(repo, master_ref2, old_target: commit_id_master)
      assert {:ok, [^master_ref2]} = Repository.list_refs(repo)
    end

    test "put_ref: :old_target (incorrect match)" do
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

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref2 = %Ref{
        name: "refs/heads/master",
        target: commit_id2_master
      }

      assert {:error, :old_target_not_matched} =
               Repository.put_ref(repo, master_ref2,
                 old_target: "2075df9dff2b5a10ad417586b4edde66af849bad"
               )

      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end

    test "put_ref: :old_target (does not exist)" do
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

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref2 = %Ref{
        name: "refs/heads/master2",
        target: commit_id2_master
      }

      assert {:error, :old_target_not_matched} =
               Repository.put_ref(repo, master_ref2, old_target: commit_id_master)

      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end

    test "put_ref: :old_target = :new" do
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

      assert :ok = Repository.put_ref(repo, master_ref, old_target: :new)
      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end

    test "put_ref: :old_target = :new, but target does exist" do
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

      {:ok, commit_id2_master} =
        HashObject.run('shhh... another not commit',
          repo: repo,
          type: :commit,
          validate?: false,
          write?: true
        )

      master_ref2 = %Ref{
        name: "refs/heads/master",
        target: commit_id2_master
      }

      assert {:error, :old_target_not_matched} =
               Repository.put_ref(repo, master_ref2, old_target: :new)

      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end
  end

  describe "delete_ref/3" do
    test "removes an existing ref" do
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

      assert :ok = Repository.delete_ref(repo, "refs/heads/master")

      assert {:error, :not_found} = Repository.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Repository.list_refs(repo)
    end

    test "quietly 'succeeds' if ref didn't exist" do
      {:ok, repo} = InMemory.start_link()

      assert {:ok, []} = Repository.list_refs(repo)

      assert :ok = Repository.delete_ref(repo, "refs/heads/master")

      assert {:error, :not_found} = Repository.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Repository.list_refs(repo)
    end

    test "error if name invalid" do
      {:ok, repo} = InMemory.start_link()

      assert {:ok, []} = Repository.list_refs(repo)

      assert {:error, :invalid_ref} = Repository.delete_ref(repo, "refs")

      assert {:error, :not_found} = Repository.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Repository.list_refs(repo)
    end

    test ":old_target matches existing ref" do
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

      assert :ok = Repository.delete_ref(repo, "refs/heads/master", old_target: commit_id_master)

      assert {:error, :not_found} = Repository.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Repository.list_refs(repo)
    end

    test "doesn't remove ref if :old_target doesn't match" do
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

      assert {:error, :old_target_not_matched} =
               Repository.delete_ref(repo, "refs/heads/master",
                 old_target: "bec43c416143e6b8bf9a3b559260185757e1386b"
               )

      assert {:ok, ^master_ref} = Repository.get_ref(repo, "refs/heads/master")
      assert {:ok, [^master_ref]} = Repository.list_refs(repo)
    end

    test "error if :old_target specified and no ref exists" do
      {:ok, repo} = InMemory.start_link()

      assert {:ok, []} = Repository.list_refs(repo)

      assert {:error, :old_target_not_matched} =
               Repository.delete_ref(repo, "refs/heads/master",
                 old_target: "bec43c416143e6b8bf9a3b559260185757e1386b"
               )

      assert {:error, :not_found} = Repository.get_ref(repo, "refs/heads/master")
      assert {:ok, []} = Repository.list_refs(repo)
    end
  end
end
