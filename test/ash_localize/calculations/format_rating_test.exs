defmodule AshLocalize.Calculations.FormatRatingTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatRating

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires :field" do
      assert {:error, _} = FormatRating.init(out_of: 5)
    end

    test "requires :out_of" do
      assert {:error, _} = FormatRating.init(field: :r)
    end
  end

  describe "calculate/3 — default fraction" do
    test ~S(renders "X / Y" by default) do
      {:ok, opts} = FormatRating.init(field: :r, out_of: 5)
      records = [%{r: Decimal.from_float(4.5)}, %{r: Decimal.new(3)}]
      assert FormatRating.calculate(records, opts, @context) == ["4.5 / 5", "3 / 5"]
    end

    test "returns nil for a nil value" do
      {:ok, opts} = FormatRating.init(field: :r, out_of: 5)
      assert FormatRating.calculate([%{r: nil}], opts, @context) == [nil]
    end
  end

  describe "calculate/3 — plural-aware" do
    test "renders the assembled MF2 template with :one and :other" do
      {:ok, opts} =
        FormatRating.init(
          field: :r,
          out_of: 5,
          one: "{$rating} star out of {$out_of}",
          other: "{$rating} stars out of {$out_of}"
        )

      records = [%{r: Decimal.new(1)}, %{r: Decimal.from_float(4.5)}]

      assert FormatRating.calculate(records, opts, @context) ==
               ["1 star out of 5", "4.5 stars out of 5"]
    end
  end
end
