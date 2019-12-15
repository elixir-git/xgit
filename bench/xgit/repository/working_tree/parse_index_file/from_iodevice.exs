# Measure cost of Xgit.DirCache.from_iodevice/1.
#
# EXPECTED: Cost is roughly O(n) on the number of items in the index file.
#
# --------------------------------------------------------------------------------------
#
# $ mix run bench/xgit/repository/working_tree/parse_index_file/from_iodevice.exs
# Operating System: macOS
# CPU Information: Intel(R) Core(TM) i7-4980HQ CPU @ 2.80GHz
# Number of Available Cores: 8
# Available memory: 16 GB
# Elixir 1.9.1
# Erlang 22.0.7
#
# Benchmark suite executing with the following configuration:
# warmup: 2 s
# time: 5 s
# memory time: 0 ns
# parallel: 1
# inputs: 10 items, 100 items, 1000 items
# Estimated total run time: 21 s
#
# Benchmarking parse_index_file with input 10 items...
# Benchmarking parse_index_file with input 100 items...
# Benchmarking parse_index_file with input 1000 items...
#
# ##### With input 10 items #####
# Name                       ips        average  deviation         median         99th %
# parse_index_file        1.14 K      880.11 μs     ±7.61%         871 μs     1090.70 μs
#
# ##### With input 100 items #####
# Name                       ips        average  deviation         median         99th %
# parse_index_file        146.25        6.84 ms     ±3.99%        6.81 ms        7.69 ms
#
# ##### With input 1000 items #####
# Name                       ips        average  deviation         median         99th %
# parse_index_file         14.87       67.23 ms     ±1.97%       67.01 ms       73.24 ms
#
# --------------------------------------------------------------------------------------

alias Xgit.DirCache
alias Xgit.Util.TrailingHashDevice

Temp.track!()

make_index_file_with_n_entries = fn n ->
  git_dir = Temp.mkdir!()

  {_output, 0} = System.cmd("git", ["init"], cd: git_dir)

  Enum.map(1..n, fn i ->
    name = "0000#{i}"

    {_output, _0} =
      System.cmd(
        "git",
        [
          "update-index",
          "--add",
          "--cacheinfo",
          "100644",
          "18832d35117ef2f013c4009f5b2128dfaeff354f",
          "a#{String.slice(name, -4, 4)}"
        ],
        cd: git_dir
      )
  end)

  Path.join([git_dir, ".git", "index"])
end

thd_open_file! = fn path ->
  {:ok, iodevice} = TrailingHashDevice.open_file(path)
  iodevice
end

inputs = %{
  "10 items" => make_index_file_with_n_entries.(10),
  "100 items" => make_index_file_with_n_entries.(100),
  "1000 items" => make_index_file_with_n_entries.(1000)
}

Benchee.run(
  %{
    "parse_index_file" => fn index_file_path ->
      iodevice = thd_open_file!.(index_file_path)
      DirCache.from_iodevice(iodevice)
      File.close(iodevice)
    end
  },
  inputs: inputs
)
