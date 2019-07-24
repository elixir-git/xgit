defmodule FolderDiff do
  @moduledoc false
  # Split out as a separate package? Compare two folders. Assert if mismatched.

  import ExUnit.Assertions

  @spec assert_folders_are_equal(folder1 :: Path.t(), folder2 :: Path.t()) :: :ok
  def assert_folders_are_equal(folder1, folder2) do
    files1 = folder1 |> File.ls!() |> Enum.sort()
    files2 = folder2 |> File.ls!() |> Enum.sort()

    assert_folders_are_equal(folder1, folder2, files1, files2)
  end

  defp assert_folders_are_equal(folder1, folder2, [file1 | files1], [file2 | files2]) do
    cond do
      file1 == file2 ->
        assert_files_are_equal(folder1, folder2, file1)
        assert_folders_are_equal(folder1, folder2, files1, files2)

      file1 < file2 ->
        flunk_file_missing(folder1, folder2, file1)

      true ->
        flunk_file_missing(folder2, folder1, file2)
    end
  end

  defp assert_folders_are_equal(folder1, folder2, [file1 | _], []),
    do: flunk_file_missing(folder1, folder2, file1)

  defp assert_folders_are_equal(folder1, folder2, [], [file2 | _]),
    do: flunk_file_missing(folder2, folder1, file2)

  defp assert_folders_are_equal(_folder1, _folder2, [], []), do: :ok

  defp assert_files_are_equal(_folder1, _folder2, "."), do: :ok
  defp assert_files_are_equal(_folder1, _folder2, ".."), do: :ok

  defp assert_files_are_equal(folder1, folder2, file) do
    f1 = Path.join(folder1, file)
    f2 = Path.join(folder2, file)

    f1_is_dir? = File.dir?(f1)
    f2_is_dir? = File.dir?(f2)

    cond do
      f1_is_dir? and f2_is_dir? -> assert_folders_are_equal(f1, f2)
      f1_is_dir? -> flunk("#{f1} is a directory; #{f2} is a file")
      f2_is_dir? -> flunk("#{f1} is a file; #{f2} is a directory")
      true -> assert_flat_files_are_equal(f1, f2)
    end
  end

  defp flunk_file_missing(folder_present, folder_missing, file) do
    flunk("File #{file} exists in folder #{folder_present}, but is missing in #{folder_missing}")
  end

  defp assert_flat_files_are_equal(f1, f2) do
    c1 = File.read!(f1)
    c2 = File.read!(f2)

    unless c1 == c2 do
      c1 = truncate(c1)
      c2 = truncate(c2)

      flunk(~s"""
      Files mismatch:

      #{f1}:
      #{c1}

      #{f2}:
      #{c2}

      """)
    end
  end

  defp truncate(c) do
    length = String.length(c)

    if String.valid?(c) do
      if length > 500 do
        ~s"""
        #{length} bytes starting with:
        #{String.slice(c, 0, 500)}
        """
      else
        c
      end
    else
      if length > 100 do
        ~s"""
        #{length} bytes starting with:
        #{inspect(:binary.bin_to_list(c, 0, 100))}
        """
      else
        inspect(:binary.bin_to_list(c))
      end
    end
  end
end
