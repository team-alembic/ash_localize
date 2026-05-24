defmodule AshLocalize.Types.RatioTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Ratio

  test "casts a float to Decimal" do
    assert {:ok, %Decimal{}} = Ratio.cast_input(0.75, [])
  end

  test "rejects a non-number" do
    assert {:error, _} = Ratio.cast_input("0.75", [])
  end

  test "applies the default 0..1 bounds" do
    assert :ok = Ratio.apply_constraints(Decimal.new("0.5"), min: 0.0, max: 1.0)
    assert {:error, _} = Ratio.apply_constraints(Decimal.new("-0.1"), min: 0.0, max: 1.0)
    assert {:error, _} = Ratio.apply_constraints(Decimal.new("1.5"), min: 0.0, max: 1.0)
  end

  test "passes nil through" do
    assert Ratio.cast_input(nil, []) == {:ok, nil}
    assert :ok = Ratio.apply_constraints(nil, [])
  end

  test "storage_type/1 is :decimal" do
    assert Ratio.storage_type([]) == :decimal
  end
end
