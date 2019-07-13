defmodule Xgit.Repository.OnDisk.Create do
  @moduledoc false
  # Implements Xgit.Repository.OnDisk.create/1.

  def create(opts) when is_list(opts) do
    work_dir = Keyword.get(opts, :work_dir)

    unless is_binary(work_dir) do
      raise ArgumentError, "Xgit.Repository.OnDisk.create/1: :work_dir must be a file path"
    end

    work_dir
    |> assert_not_exists!()
    |> create_empty_repo!()

    :ok
  end

  defp assert_not_exists!(path) do
    if File.exists?(path) do
      raise ArgumentError,
            "Xgit.Repository.OnDisk.create/1: :work_dir must be a directory that doesn't already exist"
    else
      path
    end
  end

  defp create_empty_repo!(path) do
    File.mkdir_p!(path)

    path
    |> Path.join(".git")
    |> create_git_dir!()
  end

  defp create_git_dir!(git_dir) do
    create_branches_dir!(git_dir)
    create_config!(git_dir)
    create_description!(git_dir)
    create_head!(git_dir)
    create_hooks_dir!(git_dir)
    create_info_dir!(git_dir)
    create_objects_dir!(git_dir)
    create_refs_dir!(git_dir)
  end

  defp create_branches_dir!(git_dir) do
    git_dir
    |> Path.join("branches")
    |> File.mkdir_p!()
  end

  defp create_config!(git_dir) do
    git_dir
    |> Path.join("config")
    |> File.write!(~s"""
    [core]
    \trepositoryformatversion = 0
    \tfilemode = true
    \tbare = false
    \tlogallrefupdates = true
    """)
  end

  defp create_description!(git_dir) do
    git_dir
    |> Path.join("description")
    |> File.write!("Unnamed repository; edit this file 'description' to name the repository.\n")
  end

  defp create_head!(git_dir) do
    git_dir
    |> Path.join("HEAD")
    |> File.write!("ref: refs/heads/master\n")
  end

  defp create_hooks_dir!(git_dir) do
    git_dir
    |> Path.join("hooks")
    |> File.mkdir_p!()

    # NOTE: Intentionally not including the sample files.
  end

  defp create_info_dir!(git_dir) do
    info_dir = Path.join(git_dir, "info")
    File.mkdir_p!(info_dir)

    info_dir
    |> Path.join("exclude")
    |> File.write!(~S"""
    # git ls-files --others --exclude-from=.git/info/exclude
    # Lines that start with '#' are comments.
    # For a project mostly in C, the following would be a good set of
    # exclude patterns (uncomment them if you want to use them):
    # *.[oa]
    # *~
    .DS_Store
    """)
  end

  defp create_objects_dir!(git_dir) do
    git_dir
    |> Path.join("objects/info")
    |> File.mkdir_p!()

    git_dir
    |> Path.join("objects/pack")
    |> File.mkdir_p!()
  end

  defp create_refs_dir!(git_dir) do
    refs_dir = Path.join(git_dir, "refs")
    File.mkdir_p!(refs_dir)

    refs_dir
    |> Path.join("heads")
    |> File.mkdir_p!()

    refs_dir
    |> Path.join("tags")
    |> File.mkdir_p!()
  end
end
