defmodule AshLocalize.Types.UnitCategoryTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.{Distance, Length, Mass, Speed}

  describe "a generated category type" do
    test "defaults to its SI base unit" do
      assert {:ok, %Localize.Unit{name: "meter-per-second"}} = Speed.cast_input(7800, [])
      assert {:ok, %Localize.Unit{name: "kilogram"}} = Mass.cast_input(5, [])
    end

    test "converts a compatible unit to the base unit" do
      assert {:ok, %Localize.Unit{name: "meter-per-second"}} =
               Speed.cast_input({100, "kilometer-per-hour"}, [])
    end

    test "rejects a unit from another category" do
      assert {:error, _} = Speed.cast_input({5, "kilogram"}, [])
    end

    test "allows the base unit to be overridden per attribute" do
      assert {:ok, %Localize.Unit{name: "knot"}} = Speed.cast_input(10, base_unit: "knot")
    end

    test "storage_type defaults to :decimal" do
      assert Speed.storage_type([]) == :decimal
    end
  end

  describe "the Distance alias" do
    test "behaves identically to Length" do
      assert Distance.cast_input(5, []) == Length.cast_input(5, [])
      assert {:ok, %Localize.Unit{name: "meter"}} = Distance.cast_input(5, [])
    end
  end
end
