defmodule AshLocalize.Calculations.FormatDateTimeTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatDateTime

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires a :field option" do
      assert {:error, _} = FormatDateTime.init([])
    end

    test "accepts a :field option" do
      assert {:ok, opts} = FormatDateTime.init(field: :event_at)
      assert opts[:field] == :event_at
    end
  end

  describe "load/3" do
    test "loads the source field" do
      assert FormatDateTime.load(nil, [field: :event_at], @context) == [:event_at]
    end
  end

  describe "calculate/3" do
    test "formats a datetime in the resolved locale" do
      records = [%{event_at: ~U[2026-05-22 13:45:00Z]}]

      # CLDR places a narrow no-break space (U+202F) before the day period.
      assert FormatDateTime.calculate(records, [field: :event_at], @context) ==
               ["May 22, 2026, 1:45:00 PM"]
    end

    test "returns nil for a nil value" do
      assert FormatDateTime.calculate([%{event_at: nil}], [field: :event_at], @context) == [nil]
    end
  end
end
