defmodule AshLocalize.Types.OrdinalTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Ordinal

  describe "cast_input/2" do
    test "accepts an integer" do
      assert Ordinal.cast_input(3, []) == {:ok, 3}
    end

    test "rejects non-integers" do
      assert {:error, _} = Ordinal.cast_input(1.5, [])
      assert {:error, _} = Ordinal.cast_input("3", [])
    end

    test "passes nil through" do
      assert Ordinal.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "apply_constraints/2" do
    test "defaults min to 1" do
      assert :ok = Ordinal.apply_constraints(1, min: 1)
      assert {:error, _} = Ordinal.apply_constraints(0, min: 1)
    end

    test "respects a max" do
      assert :ok = Ordinal.apply_constraints(5, min: 1, max: 10)
      assert {:error, _} = Ordinal.apply_constraints(11, min: 1, max: 10)
    end
  end

  describe "storage" do
    test "storage_type/1 is :integer" do
      assert Ordinal.storage_type([]) == :integer
    end
  end
end
