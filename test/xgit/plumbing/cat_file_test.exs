defmodule Xgit.Plumbing.CatFileTest do
  use Xgit.GitInitTestCase, async: true

  alias Xgit.Plumbing.CatFile
  alias Xgit.Plumbing.HashObject
  alias Xgit.Repository.OnDisk

  defmodule NotRepo do
    use GenServer

    @impl true
    def init(_init_arg), do: {:ok, nil}

    @impl true
    def handle_call(_request, _from, _state), do: {:reply, :whatever, nil}
  end

  describe "run/2" do
    test "happy path: can read from command-line git (small file)", %{ref: ref} do
      Temp.track!()
      path = Temp.path!()
      File.write!(path, "test content\n")

      {output, 0} = System.cmd("git", ["hash-object", "-w", path], cd: ref)
      test_content_id = String.trim(output)

      assert {:ok, repo} = OnDisk.start_link(work_dir: ref)

      assert {:ok, %{type: :blob, size: 13, content: test_content} = object} =
               CatFile.run(repo, test_content_id)

      assert Enum.to_list(test_content) == 'test content\n'
    end

    test "happy path: can read back from Xgit-written loose object", %{xgit: xgit} do
      assert :ok = OnDisk.create(xgit)
      assert {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      {:ok, test_content_id} = HashObject.run("test content\n", repo: repo, write?: true)

      assert {:ok, %{type: :blob, size: 13, content: test_content} = object} =
               CatFile.run(repo, test_content_id)

      assert Enum.to_list(test_content) == 'test content\n'
    end

    test "error: not_found", %{xgit: xgit} do
      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert {:error, :not_found} = CatFile.run(repo, "6c22d81cc51c6518e4625a9fe26725af52403b4f")
    end

    test "error: invalid_object", %{xgit: xgit} do
      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      path = Path.join([xgit, ".git", "objects", "5c"])
      File.mkdir_p!(path)

      File.write!(
        Path.join(path, "b5d77be2d92c7368038dac67e648a69e0a654d"),
        <<120, 1, 75, 202, 201, 79, 170, 80, 48, 52, 50, 54, 97, 0, 0, 22, 54, 3, 2>>
      )

      assert {:error, :invalid_object} =
               CatFile.run(repo, "5cb5d77be2d92c7368038dac67e648a69e0a654d")
    end

    test "error: repository invalid (not PID)" do
      assert_raise FunctionClauseError, fn ->
        CatFile.run("xgit repo", "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
      end
    end

    test "error: repository invalid (PID, but not repo)" do
      {:ok, not_repo} = GenServer.start_link(NotRepo, [])

      assert {:error, :invalid_repository} =
               CatFile.run(not_repo, "18a4a651653d7caebd3af9c05b0dc7ffa2cd0ae0")
    end

    test "error: object_id invalid (not binary)", %{xgit: xgit} do
      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert_raise FunctionClauseError, fn ->
        CatFile.run(repo, 0x18A4)
      end
    end

    test "error: object_id invalid (binary, but not valid object ID)", %{xgit: xgit} do
      :ok = OnDisk.create(xgit)
      {:ok, repo} = OnDisk.start_link(work_dir: xgit)

      assert {:error, :invalid_object_id} = CatFile.run(repo, "some random ID that isn't valid")
    end
  end
end
