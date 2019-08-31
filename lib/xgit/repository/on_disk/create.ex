defmodule Xgit.Repository.OnDisk.Create do
  @moduledoc false
  # Implements Xgit.Repository.OnDisk.create/1.

  import Xgit.Util.ForceCoverage

  @spec create(work_dir :: String.t()) :: :ok | {:error, reason :: String.t()}
  def create(work_dir) when is_binary(work_dir) do
    work_dir
    |> assert_not_exists()
    |> create_empty_repo()
  end

  defp assert_not_exists(path) do
    if File.exists?(path) do
      cover {:error, :work_dir_must_not_exist}
    else
      cover {:ok, path}
    end
  end

  defp create_empty_repo({:error, reason}), do: cover({:error, reason})

  defp create_empty_repo({:ok, path}) do
    with :ok <- File.mkdir_p(path),
         :ok <- create_git_dir(Path.join(path, ".git")) do
      cover :ok
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp create_git_dir(git_dir) do
    with :ok <- create_branches_dir(git_dir),
         :ok <- create_config(git_dir),
         :ok <- create_description(git_dir),
         :ok <- create_head(git_dir),
         :ok <- create_hooks_dir(git_dir),
         :ok <- create_info_dir(git_dir),
         :ok <- create_objects_dir(git_dir),
         :ok <- create_refs_dir(git_dir) do
      cover :ok
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp create_branches_dir(git_dir) do
    git_dir
    |> Path.join("branches")
    |> File.mkdir_p()
  end

  defp create_config(git_dir) do
    git_dir
    |> Path.join("config")
    |> File.write(~s"""
    [core]
    \trepositoryformatversion = 0
    \tfilemode = true
    \tbare = false
    \tlogallrefupdates = true
    """)
  end

  defp create_description(git_dir) do
    git_dir
    |> Path.join("description")
    |> File.write("Unnamed repository; edit this file 'description' to name the repository.\n")
  end

  defp create_head(git_dir) do
    git_dir
    |> Path.join("HEAD")
    |> File.write("ref: refs/heads/master\n")
  end

  defp create_hooks_dir(git_dir) do
    git_dir
    |> Path.join("hooks")
    |> File.mkdir_p()

    # NOTE: Intentionally not including the sample files.
  end

  defp create_info_dir(git_dir) do
    with info_dir <- Path.join(git_dir, "info"),
         :ok <- File.mkdir_p(info_dir) do
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
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp create_objects_dir(git_dir) do
    with :ok <- File.mkdir_p(Path.join(git_dir, "objects/info")),
         :ok <- File.mkdir_p(Path.join(git_dir, "objects/pack")) do
      cover :ok
    else
      {:error, reason} -> cover {:error, reason}
    end
  end

  defp create_refs_dir(git_dir) do
    refs_dir = Path.join(git_dir, "refs")

    with :ok <- File.mkdir_p(refs_dir),
         :ok <- File.mkdir_p(Path.join(refs_dir, "heads")),
         :ok <- File.mkdir_p(Path.join(refs_dir, "tags")) do
      cover :ok
    else
      {:error, reason} -> cover {:error, reason}
    end
  end
end
