defmodule AshLocalize.UnitTypeTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Test.Jerk

  describe "a category-less custom unit type (Jerk)" do
    test "defaults to its base unit on a bare number" do
      assert {:ok, %Localize.Unit{name: "meter-per-cubic-second"}} = Jerk.cast_input(9, [])
    end

    test "converts a dimensionally-compatible unit" do
      assert {:ok, %Localize.Unit{name: "meter-per-cubic-second"}} =
               Jerk.cast_input({1, "foot-per-cubic-second"}, [])
    end

    test "rejects a unit from another dimension" do
      assert {:error, _} = Jerk.cast_input({5, "kilogram"}, [])
    end

    test "allows the base unit to be overridden per attribute" do
      assert {:ok, %Localize.Unit{name: "foot-per-cubic-second"}} =
               Jerk.cast_input(1, base_unit: "foot-per-cubic-second")
    end

    test "storage_type defaults to :decimal" do
      assert Jerk.storage_type([]) == :decimal
    end
  end

  describe "the defunit/2 shortcut" do
    alias AshLocalize.Test.JerkShortcut

    test "defines a working unit type in one line" do
      assert {:ok, %Localize.Unit{name: "meter-per-cubic-second"}} =
               JerkShortcut.cast_input(9, [])
    end

    test "the defined type still rejects incompatible units" do
      assert {:error, _} = JerkShortcut.cast_input({5, "kilogram"}, [])
    end
  end
end
