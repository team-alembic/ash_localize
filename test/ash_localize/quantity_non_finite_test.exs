defmodule AshLocalize.QuantityNonFiniteTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.{Count, Percentage, Rating, Ratio, Score}

  @non_finite ["NaN", "Infinity", "-Infinity"]

  describe "decimal-storage quantity types refuse non-finite values" do
    for type <- [Percentage, Ratio, Score, Rating] do
      test "#{inspect(type)}" do
        for text <- @non_finite do
          assert {:error, message: "is not a number"} =
                   unquote(type).cast_input(Decimal.new(text), [])
        end
      end
    end

    test "through Ash.Type.cast_input with unbounded constraints" do
      {:ok, constraints} = Ash.Type.init(:percentage, min: nil, max: nil)

      for text <- @non_finite do
        assert {:error, _} = Ash.Type.cast_input(:percentage, Decimal.new(text), constraints)
      end
    end

    test "finite Decimals still cast" do
      assert {:ok, %Decimal{}} = Percentage.cast_input(Decimal.new("0.5"), [])
    end

    test "integer storage is unaffected" do
      assert {:ok, 3} = Count.cast_input(3, [])
    end
  end

  describe "nil bounds" do
    test "max: nil is accepted and leaves the upper side unbounded" do
      assert {:ok, constraints} = Ash.Type.init(:percentage, max: nil)
      assert {:ok, _} = Ash.Type.apply_constraints(:percentage, Decimal.new("1000"), constraints)
      assert {:error, _} = Ash.Type.apply_constraints(:percentage, Decimal.new("-1"), constraints)
    end

    test "min: nil is accepted and leaves the lower side unbounded" do
      assert {:ok, constraints} = Ash.Type.init(:percentage, min: nil)
      assert {:ok, _} = Ash.Type.apply_constraints(:percentage, Decimal.new("-5"), constraints)
      assert {:error, _} = Ash.Type.apply_constraints(:percentage, Decimal.new("2"), constraints)
    end

    test "integer-storage types accept nil" do
      assert {:ok, constraints} = Ash.Type.init(:count, min: nil, max: nil)
      assert {:ok, _} = Ash.Type.apply_constraints(:count, -10, constraints)
      assert {:ok, _} = Ash.Type.apply_constraints(:count, 10_000_000, constraints)
    end

    test "a required upper bound still refuses nil" do
      assert {:error, _} = Ash.Type.init(:rating, out_of: nil)
    end

    test "default and explicit integer or float bounds are unchanged" do
      assert {:ok, defaults} = Ash.Type.init(:percentage, [])
      assert defaults[:min] == 0.0
      assert defaults[:max] == 1.0
      assert {:ok, _} = Ash.Type.init(:percentage, min: 0, max: 2.5)
      assert {:ok, _} = Ash.Type.init(:score, min: 0, max: 100)
    end
  end
end
