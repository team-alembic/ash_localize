defmodule AshLocalize.Types.ScoreTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Score

  test "casts a number to Decimal" do
    assert {:ok, %Decimal{}} = Score.cast_input(87, [])
    assert {:ok, %Decimal{}} = Score.cast_input(87.5, [])
  end

  test "no bounds by default" do
    assert :ok = Score.apply_constraints(Decimal.new("87"), [])
    assert :ok = Score.apply_constraints(Decimal.new("-100000"), [])
  end

  test "respects min and max when given" do
    assert :ok = Score.apply_constraints(Decimal.new("50"), min: 0, max: 100)
    assert {:error, _} = Score.apply_constraints(Decimal.new("-1"), min: 0)
    assert {:error, _} = Score.apply_constraints(Decimal.new("101"), max: 100)
  end

  test "storage_type/1 is :decimal" do
    assert Score.storage_type([]) == :decimal
  end
end
