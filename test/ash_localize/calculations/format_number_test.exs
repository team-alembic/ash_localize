defmodule AshLocalize.Calculations.FormatNumberTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatNumber

  # A calculation context that resolves to the application default locale ("en").
  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires a :field option" do
      assert {:error, _} = FormatNumber.init([])
    end

    test "accepts a :field option" do
      assert {:ok, opts} = FormatNumber.init(field: :price)
      assert opts[:field] == :price
    end
  end

  describe "load/3" do
    test "loads the source field" do
      assert FormatNumber.load(nil, [field: :price], @context) == [:price]
    end
  end

  describe "calculate/3" do
    test "formats a decimal in the resolved locale" do
      records = [%{price: Decimal.new("1234.5")}]
      assert FormatNumber.calculate(records, [field: :price], @context) == ["1,234.5"]
    end

    test "formats an integer" do
      assert FormatNumber.calculate([%{price: 1234}], [field: :price], @context) == ["1,234"]
    end

    test "returns nil for a nil value" do
      assert FormatNumber.calculate([%{price: nil}], [field: :price], @context) == [nil]
    end

    test "formats each record in the batch independently" do
      records = [%{price: 1234}, %{price: nil}, %{price: Decimal.new("1234.5")}]

      assert FormatNumber.calculate(records, [field: :price], @context) ==
               ["1,234", nil, "1,234.5"]
    end
  end
end
