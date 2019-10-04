defmodule Xgit.Plumbing.CommitTreeTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Object
  alias Xgit.Core.PersonIdent
  # alias Xgit.GitInitTestCase
  alias Xgit.Plumbing.CommitTree
  # alias Xgit.Plumbing.HashObject
  # alias Xgit.Plumbing.UpdateIndex.CacheInfo
  # alias Xgit.Plumbing.WriteTree
  alias Xgit.Repository
  # alias Xgit.Repository.WorkingTree
  alias Xgit.Test.OnDiskRepoTestCase

  # import FolderDiff

  describe "run/2" do
    @valid_pi %PersonIdent{
      name: "A. U. Thor",
      email: "author@example.com",
      when: 1_142_878_501_000,
      tz_offset: 150
    }

    test "error: invalid repo" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert {:error, :invalid_repository} =
               CommitTree.run(not_repo,
                 tree: "9d252945c1d3c553a30361214db02892d1ea4876",
                 author: @valid_pi
               )
    end

    test "error: invalid tree object ID" do
      %{xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :invalid_tree} =
               CommitTree.run(xgit_repo,
                 tree: "9d252945c1d3c553a30361214db02892d1ea487",
                 author: @valid_pi
               )
    end

    test "error: tree object doesn't exist" do
      %{xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()

      assert {:error, :invalid_tree} =
               CommitTree.run(xgit_repo,
                 tree: "9d252945c1d3c553a30361214db02892d1ea4876",
                 author: @valid_pi
               )
    end

    test "error: tree object isn't a tree" do
      %{xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()

      object = %Object{
        type: :blob,
        content: 'test content\n',
        size: 13,
        id: "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
      }

      :ok = Repository.put_loose_object(xgit_repo, object)

      assert {:error, :invalid_tree} =
               CommitTree.run(xgit_repo,
                 tree: "d670460b4b4aece5915caf5c68d12f560a9fe3e4",
                 author: @valid_pi
               )
    end
  end
end
