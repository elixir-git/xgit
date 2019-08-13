defmodule Xgit.Core.ObjectTest do
  use ExUnit.Case, async: true

  alias Xgit.Core.Object

  @valid_object_types [:blob, :tree, :commit, :tag]
  @invalid_object_types [:mumble, 1, "blob", 'blob', %{blob: true}, {:blob}, self()]

  describe "valid?/1" do
    test "accepts known object types" do
      for t <- @valid_object_types do
        assert Object.valid?(%Object{
                 type: t,
                 content: [],
                 size: 0,
                 id: "cfe0d2db02d583680f90301ff76e0791d9353335"
               })
      end
    end

    test "rejects invalid types" do
      for t <- @invalid_object_types do
        refute Object.valid?(%Object{
                 type: t,
                 content: [],
                 size: 0,
                 id: "cfe0d2db02d583680f90301ff76e0791d9353335"
               })
      end
    end

    test "rejects nil object type" do
      refute Object.valid?(%Object{
               type: :blob,
               content: nil,
               size: 0,
               id: "cfe0d2db02d583680f90301ff76e0791d9353335"
             })
    end

    @invalid_sizes [-1, -43, 3.14, "big", :small, true]
    test "rejects invalid sizes" do
      for t <- @invalid_sizes do
        refute Object.valid?(%Object{
                 type: :blob,
                 content: [],
                 size: t,
                 id: "cfe0d2db02d583680f90301ff76e0791d9353335"
               })
      end
    end

    @invalid_object_ids [
      "1234567890abcdef1231234567890abcdef1234",
      "1234567890abcdef123451234567890abcdef1234",
      0xCFE0D2DB02D583680F90301FF76E0791D9353335,
      'cfe0d2db02d583680f90301ff76e0791d9353335',
      "Cfe0d2db02d583680f90301ff76e0791d9353335",
      "cfg0d2db02d583680f90301ff76e0791d9353335"
    ]

    test "rejects invalid object IDs" do
      for id <- @invalid_object_ids do
        refute Object.valid?(%Object{type: :blob, content: [], size: 0, id: id})
      end
    end
  end
end
