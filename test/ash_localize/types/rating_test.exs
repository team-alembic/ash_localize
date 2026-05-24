defmodule AshLocalize.Types.RatingTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Rating

  test "casts a number to Decimal" do
    assert {:ok, %Decimal{}} = Rating.cast_input(4.5, [])
  end

  test "enforces 0 <= value <= out_of" do
    assert :ok = Rating.apply_constraints(Decimal.from_float(4.5), out_of: 5, min: 0.0)
    assert {:error, _} = Rating.apply_constraints(Decimal.from_float(-0.1), out_of: 5, min: 0.0)
    assert {:error, _} = Rating.apply_constraints(Decimal.from_float(5.5), out_of: 5, min: 0.0)
  end

  test "passes nil through" do
    assert Rating.cast_input(nil, []) == {:ok, nil}
    assert :ok = Rating.apply_constraints(nil, [])
  end

  test "storage_type/1 is :decimal" do
    assert Rating.storage_type([]) == :decimal
  end
end
