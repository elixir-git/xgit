defmodule Xgit.Repository.Test.RefTest do
  @moduledoc false

  # Not normally part of the public API, but available for implementors of
  # `Xgit.Repository.Storage` behaviour modules. Tests the callbacks related to
  # `Xgit.Core.Ref` to ensure correct implementation of the core contracts.
  # Other tests may be necessary to ensure interop. (For example, the on-disk
  # repository test code adds more tests to ensure correct interop with
  # command-line git.)

  # Users of this module must provide a `setup` callback that provides a
  # `repo` member. This repository may be of any type, but should be "empty."
  # An empty repo has the same data structures as an on-disk repo created
  # via `git init` in a previously-empty directory.

  import Xgit.Util.SharedTestCase

  define_shared_tests do
    alias Xgit.Core.Object
    alias Xgit.Core.Ref
    alias Xgit.Repository.Plumbing
    alias Xgit.Repository.Storage

    @test_content 'test content\n'
    @test_content_id "d670460b4b4aece5915caf5c68d12f560a9fe3e4"

    describe "get_ref/2 (shared)" do
      test "default repo contains HEAD reference", %{repo: repo} do
        assert {:ok, %Xgit.Core.Ref{name: "HEAD", target: "ref: refs/heads/master"}} =
                 Storage.get_ref(repo, "HEAD", follow_link?: false)

        assert {:error, :not_found} = Storage.get_ref(repo, "HEAD", follow_link?: true)
      end

      test "not_found case", %{repo: repo} do
        assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
      end

      test "invalid_name case", %{repo: repo} do
        assert {:error, :invalid_name} = Storage.get_ref(repo, "refs/../../heads/master")
      end
    end

    describe "list_refs/2 (shared)" do
      test "null case", %{repo: repo} do
        assert {:ok, []} = Storage.list_refs(repo)
      end
    end

    describe "put_ref/3 (shared)" do
      test "error: invalid reference", %{repo: repo} do
        assert {:error, :invalid_ref} =
                 Storage.put_ref(repo, %Ref{
                   name: "refs/heads/master",
                   target: "532ad3cb2518ad13a91e717998a26a6028df062"
                 })
      end

      test "error: object must exist", %{repo: repo} do
        assert {:error, :target_not_found} =
                 Storage.put_ref(repo, %Ref{
                   name: "refs/heads/master",
                   target: "532ad3cb2518ad13a91e717998a26a6028df0623"
                 })
      end

      test "target reference need not exist", %{repo: repo} do
        assert :ok =
                 Storage.put_ref(repo, %Ref{
                   name: "refs/heads/mumble",
                   target: "ref: refs/heads/other"
                 })

        assert {:ok, %Xgit.Core.Ref{name: "refs/heads/mumble", target: "ref: refs/heads/other"}} =
                 Storage.get_ref(repo, "refs/heads/mumble", follow_link?: false)
      end

      test "object exists, but is not a commit", %{repo: repo} do
        object = %Object{type: :blob, content: @test_content, size: 13, id: @test_content_id}
        :ok = Storage.put_loose_object(repo, object)

        assert {:error, :target_not_commit} =
                 Storage.put_ref(repo, %Ref{
                   name: "refs/heads/master",
                   target: @test_content_id
                 })
      end

      test "happy path: results visible to list_refs/1 and get_ref/2", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        assert :ok = Storage.put_ref(repo, master_ref)

        assert {:ok, [^master_ref]} = Storage.list_refs(repo)

        {:ok, commit_id_other} =
          Plumbing.hash_object('shhh... another fake commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        other_ref = %Ref{
          name: "refs/heads/other",
          target: commit_id_other
        }

        assert :ok = Storage.put_ref(repo, other_ref)

        assert {:ok, ^master_ref} = Storage.get_ref(repo, "refs/heads/master")
        assert {:ok, ^other_ref} = Storage.get_ref(repo, "refs/heads/other")

        assert {:ok, [^master_ref, ^other_ref]} = Storage.list_refs(repo)
      end

      test "follows HEAD reference correctly", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        head_ref = %Ref{
          name: "HEAD",
          target: commit_id_master
        }

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        master_ref_via_head = %Ref{
          name: "HEAD",
          target: commit_id_master,
          link_target: "refs/heads/master"
        }

        assert :ok = Storage.put_ref(repo, head_ref)

        assert {:ok, [^master_ref]} = Storage.list_refs(repo)
        assert {:ok, ^master_ref} = Storage.get_ref(repo, "refs/heads/master")
        assert {:ok, ^master_ref_via_head} = Storage.get_ref(repo, "HEAD")
      end

      test "can replace an existing object ID ref with a symbolic ref", %{repo: repo} do
        {:ok, commit_id} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        foo_ref = %Ref{
          name: "refs/heads/foo",
          target: commit_id
        }

        assert :ok = Storage.put_ref(repo, foo_ref)

        assert {:ok, [^foo_ref]} = Storage.list_refs(repo)

        foo_ref2 = %Ref{
          name: "refs/heads/foo",
          target: "ref: refs/heads/master"
        }

        assert :ok = Storage.put_ref(repo, foo_ref2)

        assert {:ok, ^foo_ref2} = Storage.get_ref(repo, "refs/heads/foo", follow_link?: false)
        assert {:ok, [^foo_ref2]} = Storage.list_refs(repo)
      end

      test "can retarget a symbolic ref by using follow_link?: false", %{repo: repo} do
        foo_ref = %Ref{
          name: "refs/heads/foo",
          target: "ref: refs/heads/master"
        }

        assert :ok = Storage.put_ref(repo, foo_ref)

        assert {:ok, [^foo_ref]} = Storage.list_refs(repo)

        foo_ref2 = %Ref{
          name: "refs/heads/foo",
          target: "ref: refs/heads/other"
        }

        assert :ok = Storage.put_ref(repo, foo_ref2, follow_link?: false)

        assert {:ok, ^foo_ref2} = Storage.get_ref(repo, "refs/heads/foo", follow_link?: false)
        assert {:ok, [^foo_ref2]} = Storage.list_refs(repo)
      end

      test ":old_target option (correct match)", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        assert :ok = Storage.put_ref(repo, master_ref)
        assert {:ok, [^master_ref]} = Storage.list_refs(repo)

        {:ok, commit_id2_master} =
          Plumbing.hash_object('shhh... another not commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref2 = %Ref{
          name: "refs/heads/master",
          target: commit_id2_master
        }

        assert :ok = Storage.put_ref(repo, master_ref2, old_target: commit_id_master)
        assert {:ok, [^master_ref2]} = Storage.list_refs(repo)
      end

      test ":old_target (incorrect match)", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        assert :ok = Storage.put_ref(repo, master_ref)
        assert {:ok, [^master_ref]} = Storage.list_refs(repo)

        {:ok, commit_id2_master} =
          Plumbing.hash_object('shhh... another not commit',
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
                 Storage.put_ref(repo, master_ref2,
                   old_target: "2075df9dff2b5a10ad417586b4edde66af849bad"
                 )

        assert {:ok, [^master_ref]} = Storage.list_refs(repo)
      end

      test "put_ref: :old_target (does not exist)", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        assert :ok = Storage.put_ref(repo, master_ref)
        assert {:ok, [^master_ref]} = Storage.list_refs(repo)

        {:ok, commit_id2_master} =
          Plumbing.hash_object('shhh... another not commit',
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
                 Storage.put_ref(repo, master_ref2, old_target: commit_id_master)

        assert {:ok, [^master_ref]} = Storage.list_refs(repo)
      end

      test ":old_target = :new", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        assert :ok = Storage.put_ref(repo, master_ref, old_target: :new)
        assert {:ok, [^master_ref]} = Storage.list_refs(repo)
      end

      test ":old_target = :new, but target does exist", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        assert :ok = Storage.put_ref(repo, master_ref)
        assert {:ok, [^master_ref]} = Storage.list_refs(repo)

        {:ok, commit_id2_master} =
          Plumbing.hash_object('shhh... another not commit',
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
                 Storage.put_ref(repo, master_ref2, old_target: :new)

        assert {:ok, [^master_ref]} = Storage.list_refs(repo)
      end
    end

    describe "delete_ref/3 (shared)" do
      test "removes an existing ref", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        assert :ok = Storage.put_ref(repo, master_ref)

        assert {:ok, [^master_ref]} = Storage.list_refs(repo)

        assert :ok = Storage.delete_ref(repo, "refs/heads/master")

        assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
        assert {:ok, []} = Storage.list_refs(repo)
      end

      test "quietly 'succeeds' if ref didn't exist", %{repo: repo} do
        assert {:ok, []} = Storage.list_refs(repo)

        assert :ok = Storage.delete_ref(repo, "refs/heads/master")

        assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
        assert {:ok, []} = Storage.list_refs(repo)
      end

      test "error if name invalid", %{repo: repo} do
        assert {:ok, []} = Storage.list_refs(repo)

        assert {:error, :invalid_ref} = Storage.delete_ref(repo, "refs")

        assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
        assert {:ok, []} = Storage.list_refs(repo)
      end

      test ":old_target matches existing ref", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        assert :ok = Storage.put_ref(repo, master_ref)

        assert {:ok, [^master_ref]} = Storage.list_refs(repo)

        assert :ok = Storage.delete_ref(repo, "refs/heads/master", old_target: commit_id_master)

        assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
        assert {:ok, []} = Storage.list_refs(repo)
      end

      test "doesn't remove ref if :old_target doesn't match", %{repo: repo} do
        {:ok, commit_id_master} =
          Plumbing.hash_object('shhh... not really a commit',
            repo: repo,
            type: :commit,
            validate?: false,
            write?: true
          )

        master_ref = %Ref{
          name: "refs/heads/master",
          target: commit_id_master
        }

        assert :ok = Storage.put_ref(repo, master_ref)

        assert {:ok, [^master_ref]} = Storage.list_refs(repo)

        assert {:error, :old_target_not_matched} =
                 Storage.delete_ref(repo, "refs/heads/master",
                   old_target: "bec43c416143e6b8bf9a3b559260185757e1386b"
                 )

        assert {:ok, ^master_ref} = Storage.get_ref(repo, "refs/heads/master")
        assert {:ok, [^master_ref]} = Storage.list_refs(repo)
      end

      test "error if :old_target specified and no ref exists", %{repo: repo} do
        assert {:ok, []} = Storage.list_refs(repo)

        assert {:error, :old_target_not_matched} =
                 Storage.delete_ref(repo, "refs/heads/master",
                   old_target: "bec43c416143e6b8bf9a3b559260185757e1386b"
                 )

        assert {:error, :not_found} = Storage.get_ref(repo, "refs/heads/master")
        assert {:ok, []} = Storage.list_refs(repo)
      end
    end
  end
end
