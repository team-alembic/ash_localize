defmodule AshLocalize.Calculations.FormatCurrencyTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatCurrency

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires a :field option" do
      assert {:error, _} = FormatCurrency.init(currency: "USD")
    end

    test "accepts :field alone (currency may come from a Money value at runtime)" do
      assert {:ok, _opts} = FormatCurrency.init(field: :price)
    end

    test "accepts :field with a static :currency" do
      assert {:ok, _opts} = FormatCurrency.init(field: :price, currency: "USD")
    end

    test "accepts :field with a :currency_field" do
      assert {:ok, _opts} = FormatCurrency.init(field: :price, currency_field: :currency)
    end
  end

  describe "load/3" do
    test "loads only the amount field for a static currency" do
      assert FormatCurrency.load(nil, [field: :price, currency: "USD"], @context) == [:price]
    end

    test "loads the amount and currency fields for a dynamic currency" do
      loaded = FormatCurrency.load(nil, [field: :price, currency_field: :currency], @context)
      assert Enum.sort(loaded) == [:currency, :price]
    end
  end

  describe "calculate/3" do
    test "formats with a static currency" do
      records = [%{price: Decimal.new("1234.5")}]
      opts = [field: :price, currency: "USD"]
      assert FormatCurrency.calculate(records, opts, @context) == ["$1,234.50"]
    end

    test "formats with a per-record currency from a sibling field" do
      records = [%{price: Decimal.new("1234.5"), currency: "USD"}]
      opts = [field: :price, currency_field: :currency]
      assert FormatCurrency.calculate(records, opts, @context) == ["$1,234.50"]
    end

    test "returns nil for a nil amount" do
      opts = [field: :price, currency: "USD"]
      assert FormatCurrency.calculate([%{price: nil}], opts, @context) == [nil]
    end

    test "returns nil when the per-record currency is missing" do
      records = [%{price: Decimal.new("1234.5"), currency: nil}]
      opts = [field: :price, currency_field: :currency]
      assert FormatCurrency.calculate(records, opts, @context) == [nil]
    end

    test "formats a %Money{} source — currency comes from the value itself" do
      records = [%{price: Money.new(:USD, "1234.5")}]
      opts = [field: :price]
      assert FormatCurrency.calculate(records, opts, @context) == ["$1,234.50"]
    end

    test "%Money{} ignores :currency / :currency_field — the value is authoritative" do
      records = [%{price: Money.new(:JPY, 1500), currency: "USD"}]

      # Static :currency is overridden by the Money's own currency.
      assert FormatCurrency.calculate(records, [field: :price, currency: "USD"], @context) ==
               ["¥1,500"]

      # :currency_field likewise.
      assert FormatCurrency.calculate(
               records,
               [field: :price, currency_field: :currency],
               @context
             ) == ["¥1,500"]
    end
  end
end
