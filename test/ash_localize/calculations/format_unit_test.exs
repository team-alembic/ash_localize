defmodule AshLocalize.Calculations.FormatUnitTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatUnit

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires a :field option" do
      assert {:error, _} = FormatUnit.init([])
    end

    test "accepts a :field option" do
      assert {:ok, opts} = FormatUnit.init(field: :delta_v)
      assert opts[:field] == :delta_v
    end
  end

  describe "load/3" do
    test "loads the source field" do
      assert FormatUnit.load(nil, [field: :delta_v], @context) == [:delta_v]
    end
  end

  describe "calculate/3" do
    test "formats a quantity in the resolved locale" do
      records = [%{delta_v: Localize.Unit.new!(7800, "meter-per-second")}]

      assert FormatUnit.calculate(records, [field: :delta_v], @context) ==
               ["7,800 meters per second"]
    end

    test "returns nil for a nil value" do
      assert FormatUnit.calculate([%{delta_v: nil}], [field: :delta_v], @context) == [nil]
    end
  end
end
