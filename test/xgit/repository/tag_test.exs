defmodule Xgit.Repository.TagTest do
  use ExUnit.Case, async: true

  # alias Xgit.PersonIdent
  alias Xgit.Repository
  alias Xgit.Repository.InMemory
  alias Xgit.Repository.InvalidRepositoryError
  # alias Xgit.Repository.Plumbing
  # alias Xgit.Repository.Storage
  alias Xgit.Test.OnDiskRepoTestCase

  import FolderDiff
  import Xgit.Test.OnDiskRepoTestCase, only: [setup_with_valid_parent_commit!: 0]

  describe "tag/4" do
    # @valid_pi %PersonIdent{
    #   name: "A. U. Thor",
    #   email: "author@example.com",
    #   when: 1_142_878_449_000,
    #   tz_offset: 150
    # }

    @env OnDiskRepoTestCase.sample_commit_env()

    test "happy path: lightweight tag" do
      %{xgit_path: ref_path, parent_id: commit_id} = setup_with_valid_parent_commit!()

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
      %{xgit_path: ref_path, parent_id: commit_id} = setup_with_valid_parent_commit!()

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

    test "happy path: won't rewrite existing lightweight tag" do
      %{xgit_path: ref_path, parent_id: commit_id} = setup_with_valid_parent_commit!()

      assert {_, 0} =
               System.cmd("git", ["tag", "sample-tag", commit_id],
                 cd: ref_path,
                 env: @env
               )

      assert {_, 0} =
               System.cmd("git", ["commit", "--allow-empty", "--message", "another commit"],
                 cd: ref_path,
                 env: @env
               )

      assert {commit2_id_str, 0} =
               System.cmd("git", ["log", "-1", "--pretty=format:%H"], cd: ref_path)

      commit2_id = String.trim(commit2_id_str)

      assert {_, 128} =
               System.cmd("git", ["tag", "sample-tag", commit2_id],
                 cd: ref_path,
                 env: @env,
                 stderr_to_stdout: true
               )

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, parent_id: commit_id} =
        setup_with_valid_parent_commit!()

      assert {_, 0} =
               System.cmd("git", ["tag", "sample-tag", commit_id],
                 cd: xgit_path,
                 env: @env
               )

      assert {_, 0} =
               System.cmd("git", ["commit", "--allow-empty", "--message", "another commit"],
                 cd: xgit_path,
                 env: @env
               )

      assert {commit2_id_str, 0} =
               System.cmd("git", ["log", "-1", "--pretty=format:%H"], cd: xgit_path)

      commit2_id = String.trim(commit2_id_str)

      assert {:error, :old_target_not_matched} =
               Repository.tag(xgit_repo, "sample-tag", commit2_id, annotated?: false)

      assert_folders_are_equal(ref_path, xgit_path)
    end

    test "happy path: will rewrite existing lightweight tag with force?: true" do
      %{xgit_path: ref_path, parent_id: commit_id} = setup_with_valid_parent_commit!()

      assert {_, 0} =
               System.cmd("git", ["tag", "sample-tag", commit_id],
                 cd: ref_path,
                 env: @env
               )

      assert {_, 0} =
               System.cmd("git", ["commit", "--allow-empty", "--message", "another commit"],
                 cd: ref_path,
                 env: @env
               )

      assert {commit2_id_str, 0} =
               System.cmd("git", ["log", "-1", "--pretty=format:%H"], cd: ref_path)

      commit2_id = String.trim(commit2_id_str)

      assert {_, 0} =
               System.cmd("git", ["tag", "-f", "sample-tag", commit2_id],
                 cd: ref_path,
                 env: @env
               )

      %{xgit_path: xgit_path, xgit_repo: xgit_repo, parent_id: commit_id} =
        setup_with_valid_parent_commit!()

      assert {_, 0} =
               System.cmd("git", ["tag", "sample-tag", commit_id],
                 cd: xgit_path,
                 env: @env
               )

      assert {_, 0} =
               System.cmd("git", ["commit", "--allow-empty", "--message", "another commit"],
                 cd: xgit_path,
                 env: @env
               )

      assert {commit2_id_str, 0} =
               System.cmd("git", ["log", "-1", "--pretty=format:%H"], cd: xgit_path)

      commit2_id = String.trim(commit2_id_str)

      assert :ok =
               Repository.tag(xgit_repo, "sample-tag", commit2_id, annotated?: false, force?: true)

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

    test "error: tag name empty" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: tag_name "" is invalid),
                   fn ->
                     Repository.tag(repo, "", "9d252945c1d3c553a30361214db02892d1ea4876")
                   end
    end

    test "error: tag name invalid" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: tag_name "abc.lock" is invalid),
                   fn ->
                     Repository.tag(repo, "abc.lock", "9d252945c1d3c553a30361214db02892d1ea4876")
                   end
    end

    test "error: object ID invalid" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: object "9d252945c1d3c553a30361214db02892d1ea487" is invalid),
                   fn ->
                     Repository.tag(repo, "abc", "9d252945c1d3c553a30361214db02892d1ea487")
                     # This object name is 39 hex digits, not 40.
                   end
    end

    test "error: force? option value is invalid" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: force? "yes" is invalid),
                   fn ->
                     Repository.tag(repo, "abc", "9d252945c1d3c553a30361214db02892d1ea4876",
                       force?: "yes"
                     )
                   end
    end

    test "error: message value is empty" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: message must be non-empty if present),
                   fn ->
                     Repository.tag(repo, "abc", "9d252945c1d3c553a30361214db02892d1ea4876",
                       message: ''
                     )
                   end
    end

    test "error: message value is empty (string)" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: message must be non-empty if present),
                   fn ->
                     Repository.tag(repo, "abc", "9d252945c1d3c553a30361214db02892d1ea4876",
                       message: ""
                     )
                   end
    end

    test "error: message value is empty (charlist)" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: message must be non-empty if present),
                   fn ->
                     Repository.tag(repo, "abc", "9d252945c1d3c553a30361214db02892d1ea4876",
                       message: ''
                     )
                   end
    end

    test "error: message value is invalid" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: message :message is invalid),
                   fn ->
                     Repository.tag(repo, "abc", "9d252945c1d3c553a30361214db02892d1ea4876",
                       message: :message
                     )
                   end
    end

    test "error: annotated? and message mismatch 1" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: annotated?: false can not be specified when message is present),
                   fn ->
                     Repository.tag(repo, "abc", "9d252945c1d3c553a30361214db02892d1ea4876",
                       message: "message",
                       annotated?: false
                     )
                   end
    end

    test "error: annotated? and message mismatch 2" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: annotated?: true can not be specified without message),
                   fn ->
                     Repository.tag(repo, "abc", "9d252945c1d3c553a30361214db02892d1ea4876",
                       annotated?: true
                     )
                   end
    end

    test "error: annotated value is invalid" do
      {:ok, repo} = InMemory.start_link()

      assert_raise ArgumentError,
                   ~S(Xgit.Repository.tag/4: annotated? "yes" is invalid),
                   fn ->
                     Repository.tag(repo, "abc", "9d252945c1d3c553a30361214db02892d1ea4876",
                       annotated?: "yes"
                     )
                   end
    end
  end
end
