defmodule AshLocalize.Calculations.FormatPercentTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatPercent

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires :field" do
      assert {:error, _} = FormatPercent.init([])
    end
  end

  describe "calculate/3" do
    test "formats a decimal fraction as a percentage" do
      records = [%{p: Decimal.from_float(0.75)}, %{p: Decimal.new(1)}]
      assert FormatPercent.calculate(records, [field: :p], @context) == ["75%", "100%"]
    end

    test "returns nil for a nil value" do
      assert FormatPercent.calculate([%{p: nil}], [field: :p], @context) == [nil]
    end
  end
end
