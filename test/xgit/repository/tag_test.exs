defmodule Xgit.Repository.TagTest do
  use ExUnit.Case, async: true

  # alias Xgit.PersonIdent
  alias Xgit.Repository
  alias Xgit.Repository.InvalidRepositoryError
  # alias Xgit.Repository.Plumbing
  # alias Xgit.Repository.Storage
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff

  import Xgit.Test.OnDiskRepoTestCase,
    only: [setup_with_valid_parent_commit!: 1]

  describe "tag/4" do
    # @valid_pi %PersonIdent{
    #   name: "A. U. Thor",
    #   email: "author@example.com",
    #   when: 1_142_878_449_000,
    #   tz_offset: 150
    # }

    @env OnDiskRepoTestCase.sample_commit_env()

    test "happy path: lightweight tag" do
      %{xgit_path: ref_path, parent_id: commit_id} =
        setup_with_valid_parent_commit!()

      assert {_, 0} =
               System.cmd("git", ["tag", "sample-tag", commit_id],
                 cd: ref_path,
                 env: @env
               )

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, parent_id: commit_id} =
        setup_with_valid_parent_commit!()

      assert :ok = Repository.tag(xgit_repo, "sample-tag", commit_id, annotated?: false)

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "happy path: lightweight tag as default when no message" do
      %{xgit_path: ref_path, parent_id: commit_id} =
        setup_with_valid_parent_commit!()

      assert {_, 0} =
               System.cmd("git", ["tag", "sample-tag", commit_id],
                 cd: ref_path,
                 env: @env
               )

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, parent_id: commit_id} =
        setup_with_valid_parent_commit!()

      assert :ok = Repository.tag(xgit_repo, "sample-tag", commit_id)

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "error: invalid repo" do
      {:ok, not_repo} = GenServer.start_link(NotValid, nil)

      assert_raise InvalidRepositoryError, fn ->
        assert :ok =
                 Repository.tag(
                   not_repo,
                   "sample-tag",
                   "9d252945c1d3c553a30361214db02892d1ea4876",
                   annotated?: false
                 )
      end
    end
  end
end
