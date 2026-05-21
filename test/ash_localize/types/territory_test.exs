defmodule AshLocalize.Types.TerritoryTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Territory

  describe "cast_input/2" do
    test "accepts a territory code and upcases it" do
      assert Territory.cast_input("us", []) == {:ok, "US"}
    end

    test "accepts an already-canonical territory code" do
      assert Territory.cast_input("AU", []) == {:ok, "AU"}
    end

    test "rejects an unknown territory code" do
      assert {:error, _} = Territory.cast_input("ZZZZ", [])
    end

    test "rejects a non-string value" do
      assert {:error, _} = Territory.cast_input(123, [])
    end

    test "passes nil through" do
      assert Territory.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "as an Ash.Type" do
    test "storage_type/1 is :string" do
      assert Territory.storage_type([]) == :string
    end

    test "round-trips through cast_stored/2 and dump_to_native/2" do
      assert Territory.cast_stored("AU", []) == {:ok, "AU"}
      assert Territory.cast_stored(nil, []) == {:ok, nil}
      assert Territory.dump_to_native("AU", []) == {:ok, "AU"}
      assert Territory.dump_to_native(nil, []) == {:ok, nil}
    end

    test "is recognised by Ash.Type.cast_input/3" do
      assert Ash.Type.cast_input(Territory, "us", []) == {:ok, "US"}
    end
  end
end
