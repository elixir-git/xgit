defmodule Xgit.Repository.OnDisk.ConfigTest do
  use Xgit.Repository.Test.ConfigTest, async: true

  # alias Xgit.ConfigEntry
  # alias Xgit.Repository.Plumbing
  # alias Xgit.Repository.Storage
  alias Xgit.Test.OnDiskRepoTestCase

  # import FolderDiff

  setup do
    %{xgit_repo: repo, xgit_path: path} = OnDiskRepoTestCase.repo!()
    %{repo: repo, path: path}
  end

  # describe "get_ref/2" do
  #   test "invalid ref (malformed file)", %{repo: repo, path: path} do
  #     File.write!(Path.join(path, ".git/refs/heads/master"), "not a SHA-1 hash")
  #     assert {:error, :invalid_ref} = Storage.get_ref(repo, "refs/heads/master")
  #   end

  #   test "invalid ref (dir, not file)", %{repo: repo, path: path} do
  #     File.mkdir_p!(Path.join(path, ".git/refs/heads/master"))
  #     assert {:error, :eisdir} = Storage.get_ref(repo, "refs/heads/master")
  #   end

  #   test "invalid ref (empty file)", %{repo: repo, path: path} do
  #     File.write!(Path.join(path, ".git/refs/heads/master"), "")
  #     assert {:error, :eof} = Storage.get_ref(repo, "refs/heads/master")
  #   end

  #   test "posix error", %{repo: repo, path: path} do
  #     File.mkdir_p!(Path.join(path, ".git/refs/heads/master"))
  #     assert {:error, :eisdir} = Storage.get_ref(repo, "refs/heads/master")
  #   end

  #   test "can read ref written by command-line git", %{repo: repo, path: path} do
  #     assert {_, 0} =
  #              System.cmd("git", ["commit", "--allow-empty", "--message", "foo"],
  #                cd: path,
  #                env: @env
  #              )

  #     {show_ref_output, 0} = System.cmd("git", ["show-ref", "master"], cd: path)
  #     {commit_id, _} = String.split_at(show_ref_output, 40)

  #     assert {_, 0} = System.cmd("git", ["update-ref", "refs/heads/other", commit_id], cd: path)

  #     other_ref = %Ref{
  #       name: "refs/heads/other",
  #       target: commit_id
  #     }

  #     assert {:ok, ^other_ref} = Storage.get_ref(repo, "refs/heads/other")
  #   end
  # end

  # describe "put_ref/3" do
  #   test "posix error (dir where file should be)", %{repo: repo, path: path} do
  #     File.mkdir_p!(Path.join(path, ".git/refs/heads/master"))

  #     {:ok, commit_id_master} =
  #       Plumbing.hash_object('shhh... not really a commit',
  #         repo: repo,
  #         type: :commit,
  #         validate?: false,
  #         write?: true
  #       )

  #     assert {:error, :eisdir} =
  #              Storage.put_ref(repo, %Ref{
  #                name: "refs/heads/master",
  #                target: commit_id_master
  #              })
  #   end

  #   test "posix error (file where dir should be)", %{repo: repo, path: path} do
  #     File.write!(Path.join(path, ".git/refs/heads/sub"), "oops, not a directory")

  #     {:ok, commit_id_master} =
  #       Plumbing.hash_object('shhh... not really a commit',
  #         repo: repo,
  #         type: :commit,
  #         validate?: false,
  #         write?: true
  #       )

  #     assert {:error, :eexist} =
  #              Storage.put_ref(repo, %Ref{
  #                name: "refs/heads/sub/master",
  #                target: commit_id_master
  #              })
  #   end

  #   test "result can be read by command-line git", %{repo: repo, path: path} do
  #     {:ok, commit_id_master} =
  #       Plumbing.hash_object('shhh... not really a commit',
  #         repo: repo,
  #         type: :commit,
  #         validate?: false,
  #         write?: true
  #       )

  #     master_ref = %Ref{
  #       name: "refs/heads/master",
  #       target: commit_id_master
  #     }

  #     assert :ok = Storage.put_ref(repo, master_ref)

  #     {:ok, commit_id_other} =
  #       Plumbing.hash_object('shhh... another fake commit',
  #         repo: repo,
  #         type: :commit,
  #         validate?: false,
  #         write?: true
  #       )

  #     other_ref = %Ref{
  #       name: "refs/heads/other",
  #       target: commit_id_other
  #     }

  #     assert :ok = Storage.put_ref(repo, other_ref)

  #     show_ref_output = ~s"""
  #     #{commit_id_master} refs/heads/master
  #     #{commit_id_other} refs/heads/other
  #     """

  #     assert {^show_ref_output, 0} = System.cmd("git", ["show-ref"], cd: path)
  #   end

  #   test "result matches command-line output" do
  #     %{xgit_path: xgit_path, xgit_repo: xgit_repo, parent_id: xgit_commit_id} =
  #       OnDiskRepoTestCase.setup_with_valid_parent_commit!()

  #     %{xgit_path: ref_path, parent_id: ref_commit_id} =
  #       OnDiskRepoTestCase.setup_with_valid_parent_commit!()

  #     {_, 0} = System.cmd("git", ["update-ref", "refs/heads/other", ref_commit_id], cd: ref_path)

  #     :ok = Storage.put_ref(xgit_repo, %Ref{name: "refs/heads/other", target: xgit_commit_id})

  #     assert_folders_are_equal(
  #       Path.join([ref_path, ".git", "refs"]),
  #       Path.join([xgit_path, ".git", "refs"])
  #     )
  #   end

  #   test "result matches command-line output (follow_link?: false)" do
  #     %{xgit_path: xgit_path, xgit_repo: xgit_repo} = OnDiskRepoTestCase.repo!()
  #     %{xgit_path: ref_path} = OnDiskRepoTestCase.repo!()

  #     {_, 0} =
  #       System.cmd("git", ["symbolic-ref", "refs/heads/link", "refs/heads/other"], cd: ref_path)

  #     {_, 0} =
  #       System.cmd("git", ["symbolic-ref", "refs/heads/link", "refs/heads/blah"], cd: ref_path)

  #     :ok =
  #       Storage.put_ref(
  #         xgit_repo,
  #         %Ref{name: "refs/heads/link", target: "ref: refs/heads/other"},
  #         follow_link?: false
  #       )

  #     :ok =
  #       Storage.put_ref(
  #         xgit_repo,
  #         %Ref{name: "refs/heads/link", target: "ref: refs/heads/blah"},
  #         follow_link?: false
  #       )

  #     assert_folders_are_equal(
  #       Path.join([ref_path, ".git", "refs"]),
  #       Path.join([xgit_path, ".git", "refs"])
  #     )
  #   end
  # end

  # describe "list_refs/1" do
  #   test "skips malformed file" do
  #     %{xgit_repo: repo, xgit_path: xgit_path} = OnDiskRepoTestCase.repo!()

  #     {:ok, commit_id_master} =
  #       Plumbing.hash_object('shhh... not really a commit',
  #         repo: repo,
  #         type: :commit,
  #         validate?: false,
  #         write?: true
  #       )

  #     master_ref = %Ref{
  #       name: "refs/heads/master",
  #       target: commit_id_master
  #     }

  #     assert :ok = Storage.put_ref(repo, master_ref)

  #     File.write!(Path.join(xgit_path, ".git/refs/heads/other"), "not a SHA-1 hash")

  #     assert {:ok, [^master_ref]} = Storage.list_refs(repo)
  #   end
  # end

  # describe "delete_ref/3" do
  #   test "{:error, :cant_delete_file}", %{repo: repo, path: path} do
  #     bogus_ref_path = Path.join(path, ".git/refs/heads/bogus")

  #     File.mkdir_p!(bogus_ref_path)

  #     assert {:error, :cant_delete_file} = Storage.delete_ref(repo, "refs/heads/bogus")

  #     assert File.dir?(bogus_ref_path)
  #   end

  #   test "deletion is seen by command-line git", %{repo: repo, path: path} do
  #     assert {_, 0} =
  #              System.cmd("git", ["commit", "--allow-empty", "--message", "foo"],
  #                cd: path,
  #                env: @env
  #              )

  #     {show_ref_output, 0} = System.cmd("git", ["show-ref", "master"], cd: path)
  #     {commit_id, _} = String.split_at(show_ref_output, 40)

  #     assert {_, 0} = System.cmd("git", ["update-ref", "refs/heads/other", commit_id], cd: path)
  #     assert {_, 0} = System.cmd("git", ["show-ref", "refs/heads/other"], cd: path)

  #     assert :ok = Storage.delete_ref(repo, "refs/heads/other")

  #     assert {_, 1} = System.cmd("git", ["show-ref", "refs/heads/other"], cd: path)
  #   end
  # end
end
