defmodule AshLocalize.Calculations.FormatScoreTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatScore

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  test "renders with locale-aware separators" do
    records = [%{s: Decimal.new("1234")}, %{s: Decimal.from_float(87.5)}]
    assert FormatScore.calculate(records, [field: :s], @context) == ["1,234", "87.5"]
  end

  test "returns nil for a nil value" do
    assert FormatScore.calculate([%{s: nil}], [field: :s], @context) == [nil]
  end
end
