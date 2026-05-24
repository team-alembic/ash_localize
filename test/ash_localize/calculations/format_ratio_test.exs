defmodule AshLocalize.Calculations.FormatRatioTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatRatio

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  test "renders a fraction" do
    records = [%{r: Decimal.from_float(0.75)}, %{r: Decimal.from_float(0.625)}]
    assert [a, b] = FormatRatio.calculate(records, [field: :r], @context)
    assert a =~ "3"
    assert b =~ "5"
  end

  test "returns nil for a nil value" do
    assert FormatRatio.calculate([%{r: nil}], [field: :r], @context) == [nil]
  end
end
