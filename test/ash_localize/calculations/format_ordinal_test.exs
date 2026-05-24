defmodule AshLocalize.Calculations.FormatOrdinalTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatOrdinal

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires :field" do
      assert {:error, _} = FormatOrdinal.init([])
    end
  end

  describe "calculate/3" do
    test "formats integers as English ordinals" do
      records = [%{r: 1}, %{r: 2}, %{r: 3}, %{r: 22}]

      assert FormatOrdinal.calculate(records, [field: :r], @context) == [
               "1st",
               "2nd",
               "3rd",
               "22nd"
             ]
    end

    test "returns nil for a nil value" do
      assert FormatOrdinal.calculate([%{r: nil}], [field: :r], @context) == [nil]
    end
  end
end
