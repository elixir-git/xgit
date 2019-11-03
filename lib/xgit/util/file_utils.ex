defmodule Xgit.Util.FileUtils do
  @moduledoc false

  # Internal utility for recursively listing the contents of a directory.

  import Xgit.Util.ForceCoverage

  @doc ~S"""
  Recursively list the files of a directory.

  Directories are scanned, but their paths are not reported as part of the result.
  """
  @spec recursive_files!(path :: Path.t()) :: [Path.t()]
  def recursive_files!(path \\ ".") do
    cond do
      File.regular?(path) ->
        cover [path]

      File.dir?(path) ->
        path
        |> File.ls!()
        |> Enum.map(&Path.join(path, &1))
        |> Enum.map(&recursive_files!/1)
        |> Enum.concat()

      true ->
        cover []
    end
  end
end
