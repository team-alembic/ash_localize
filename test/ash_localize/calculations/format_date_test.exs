defmodule AshLocalize.Calculations.FormatDateTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatDate

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires a :field option" do
      assert {:error, _} = FormatDate.init([])
    end

    test "accepts a :field option" do
      assert {:ok, opts} = FormatDate.init(field: :event_date)
      assert opts[:field] == :event_date
    end
  end

  describe "load/3" do
    test "loads the source field" do
      assert FormatDate.load(nil, [field: :event_date], @context) == [:event_date]
    end
  end

  describe "calculate/3" do
    test "formats a date in the resolved locale" do
      records = [%{event_date: ~D[2026-05-22]}]
      assert FormatDate.calculate(records, [field: :event_date], @context) == ["May 22, 2026"]
    end

    test "returns nil for a nil value" do
      assert FormatDate.calculate([%{event_date: nil}], [field: :event_date], @context) == [nil]
    end
  end
end
