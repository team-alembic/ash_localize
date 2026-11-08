defmodule AshLocalize.Types.UnitTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Unit

  @speed [base_unit: "meter-per-second"]

  # Conversion may yield an integer, float, or Decimal; compare numerically.
  defp num(%Decimal{} = d), do: Decimal.to_float(d)
  defp num(n), do: n / 1

  describe "cast_input/2" do
    test "casts a bare number as the base unit" do
      assert {:ok, %Localize.Unit{name: "meter-per-second"} = unit} =
               Unit.cast_input(7800, @speed)

      assert num(unit.value) == 7800.0
    end

    test "casts a {value, unit} tuple, converting to the base unit" do
      assert {:ok, %Localize.Unit{name: "meter-per-second"} = unit} =
               Unit.cast_input({2, "kilometer-per-second"}, @speed)

      assert num(unit.value) == 2000.0
    end

    test "casts a %{value:, unit:} map" do
      assert {:ok, %Localize.Unit{name: "meter-per-second"}} =
               Unit.cast_input(%{value: 2, unit: "kilometer-per-second"}, @speed)
    end

    test "casts a map with string keys" do
      assert {:ok, %Localize.Unit{name: "meter-per-second"}} =
               Unit.cast_input(%{"value" => 2, "unit" => "kilometer-per-second"}, @speed)
    end

    test "rejects a dimensionally incompatible unit" do
      assert {:error, _} = Unit.cast_input({5, "kilogram"}, @speed)
    end

    test "rejects an unknown unit" do
      assert {:error, _} = Unit.cast_input({5, "zorblaxes"}, @speed)
    end

    test "passes nil through" do
      assert Unit.cast_input(nil, @speed) == {:ok, nil}
    end
  end

  describe "storage" do
    test "storage_type defaults to :decimal" do
      assert Unit.storage_type(@speed) == :decimal
    end

    test "storage_type follows the :storage constraint" do
      assert Unit.storage_type(base_unit: "meter", storage: :float) == :float
      assert Unit.storage_type(base_unit: "meter", storage: :integer) == :integer
    end

    test "dump_to_native unwraps a quantity to its bare number" do
      {:ok, unit} = Unit.cast_input(7800, @speed)
      assert {:ok, value} = Unit.dump_to_native(unit, @speed)
      assert num(value) == 7800.0
      assert Unit.dump_to_native(nil, @speed) == {:ok, nil}
    end

    test "cast_stored re-wraps a stored number into a quantity" do
      assert {:ok, %Localize.Unit{name: "meter-per-second"} = unit} =
               Unit.cast_stored(7800, @speed)

      assert num(unit.value) == 7800.0
      assert Unit.cast_stored(nil, @speed) == {:ok, nil}
    end
  end

  describe "validate_base_unit/1" do
    test "accepts a known CLDR unit" do
      assert Unit.validate_base_unit("meter-per-second") == {:ok, "meter-per-second"}
    end

    test "rejects an unknown unit" do
      assert {:error, _} = Unit.validate_base_unit("zorblaxes")
    end
  end

  describe "the :category constraint" do
    test "accepts a unit in the declared category" do
      assert {:ok, %Localize.Unit{name: "meter-per-second"}} =
               Unit.cast_input({100, "kilometer-per-hour"},
                 base_unit: "meter-per-second",
                 category: "speed"
               )
    end

    test "rejects a unit from a different category with a category-specific message" do
      assert {:error, message: message} =
               Unit.cast_input({5, "kilogram"},
                 base_unit: "meter-per-second",
                 category: "speed"
               )

      assert message =~ "speed"
    end
  end

  describe "validate_category/1" do
    test "accepts a known CLDR category" do
      assert Unit.validate_category("speed") == {:ok, "speed"}
    end

    test "rejects an unknown category" do
      assert {:error, _} = Unit.validate_category("zorblaxes")
    end
  end

  describe "non-finite values" do
    test "a NaN or infinite Decimal is refused, bare or paired with a unit" do
      for text <- ["NaN", "Infinity", "-Infinity"] do
        value = Decimal.new(text)
        assert {:error, _} = Unit.cast_input(value, @speed)
        assert {:error, _} = Unit.cast_input({value, "kilometer-per-second"}, @speed)
        assert {:error, _} = Unit.cast_input(%{value: value, unit: "meter-per-second"}, @speed)

        assert {:error, _} =
                 Unit.cast_input(%{"value" => value, "unit" => "meter-per-second"}, @speed)
      end
    end

    test "a quantity struct holding a non-finite value is refused" do
      {:ok, quantity} = Localize.Unit.new(Decimal.new("NaN"), "meter-per-second")
      assert {:error, _} = Unit.cast_input(quantity, @speed)
    end

    test "a finite Decimal still casts" do
      assert {:ok, %Localize.Unit{}} = Unit.cast_input(Decimal.new("12.5"), @speed)
    end

    test "the per-category types refuse them too" do
      assert {:error, _} =
               AshLocalize.Types.Length.cast_input(Decimal.new("Infinity"), base_unit: "meter")
    end
  end
end
