defmodule AshLocalize.Types.PercentageTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Percentage

  describe "cast_input/2" do
    test "casts a float to Decimal" do
      assert {:ok, %Decimal{} = d} = Percentage.cast_input(0.75, [])
      assert Decimal.equal?(d, Decimal.from_float(0.75))
    end

    test "casts an integer to Decimal" do
      assert {:ok, %Decimal{}} = Percentage.cast_input(1, [])
    end

    test "passes a Decimal through" do
      d = Decimal.new("0.5")
      assert Percentage.cast_input(d, []) == {:ok, d}
    end

    test "rejects a string" do
      assert {:error, _} = Percentage.cast_input("75%", [])
    end

    test "passes nil through" do
      assert Percentage.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "apply_constraints/2" do
    test "defaults to 0..1" do
      assert :ok = Percentage.apply_constraints(Decimal.new("0.5"), min: 0.0, max: 1.0)
      assert {:error, _} = Percentage.apply_constraints(Decimal.new("-0.1"), min: 0.0, max: 1.0)
      assert {:error, _} = Percentage.apply_constraints(Decimal.new("1.5"), min: 0.0, max: 1.0)
    end

    test "respects a wider max" do
      assert :ok = Percentage.apply_constraints(Decimal.new("1.5"), min: 0.0, max: 2.0)
    end
  end

  describe "storage" do
    test "storage_type/1 is :decimal" do
      assert Percentage.storage_type([]) == :decimal
    end
  end
end
