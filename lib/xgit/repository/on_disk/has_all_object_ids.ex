defmodule Xgit.Repository.OnDisk.HasAllObjectIds do
  @moduledoc false
  # Implements Xgit.Repository.OnDisk.handle_has_all_objects?/2.

  import Xgit.Util.ForceCoverage

  alias Xgit.Core.ObjectId

  @spec handle_has_all_object_ids?(state :: any, object_ids :: [ObjectId.t()]) ::
          {:ok, has_all_object_ids? :: boolean, state :: any}
          | {:error, reason :: any, state :: any}
  def handle_has_all_object_ids?(%{git_dir: git_dir} = state, object_ids) do
    has_all_object_ids? =
      Enum.all?(object_ids, fn object_id -> has_object_id?(git_dir, object_id) end)

    cover {:ok, has_all_object_ids?, state}
  end

  defp has_object_id?(git_dir, object_id) do
    loose_object_path =
      Path.join([
        git_dir,
        "objects",
        String.slice(object_id, 0, 2),
        String.slice(object_id, 2, 38)
      ])

    File.regular?(loose_object_path)
  end
end
