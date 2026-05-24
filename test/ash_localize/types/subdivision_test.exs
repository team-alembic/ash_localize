defmodule AshLocalize.Types.SubdivisionTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Subdivision

  describe "cast_input/2" do
    test "accepts a canonical lowercase subdivision code" do
      assert Subdivision.cast_input("caon", []) == {:ok, "caon"}
    end

    test "downcases mixed-case input" do
      assert Subdivision.cast_input("CAON", []) == {:ok, "caon"}
      assert Subdivision.cast_input("CaOn", []) == {:ok, "caon"}
    end

    test "accepts a subdivision code as an atom" do
      assert Subdivision.cast_input(:caon, []) == {:ok, "caon"}
    end

    test "rejects an unknown subdivision code" do
      assert {:error, _} = Subdivision.cast_input("zzzzz", [])
    end

    test "rejects a non-string value" do
      assert {:error, _} = Subdivision.cast_input(123, [])
    end

    test "passes nil through" do
      assert Subdivision.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "constraints: :territory" do
    test "accepts a subdivision that belongs to the given territory" do
      assert Subdivision.cast_input("caon", territory: :CA) == {:ok, "caon"}
    end

    test "rejects a subdivision that does not belong to the given territory" do
      assert {:error, _} = Subdivision.cast_input("usca", territory: :CA)
    end

    test "accepts a string territory" do
      assert Subdivision.cast_input("caon", territory: "CA") == {:ok, "caon"}
    end
  end

  describe "as an Ash.Type" do
    test "storage_type/1 is :string" do
      assert Subdivision.storage_type([]) == :string
    end

    test "round-trips through cast_stored/2 and dump_to_native/2" do
      assert Subdivision.cast_stored("caon", []) == {:ok, "caon"}
      assert Subdivision.cast_stored(nil, []) == {:ok, nil}
      assert Subdivision.dump_to_native("caon", []) == {:ok, "caon"}
      assert Subdivision.dump_to_native(nil, []) == {:ok, nil}
    end

    test "is recognised by Ash.Type.cast_input/3" do
      assert Ash.Type.cast_input(Subdivision, "CAON", []) == {:ok, "caon"}
    end
  end
end
