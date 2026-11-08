defmodule AshLocalize.Types.Unit do
  @moduledoc """
  An `Ash.Type` for a CLDR unit of measure — a *dimensioned number*.

  The unit is schema metadata, not row data: the `:base_unit` constraint fixes the
  dimension and the unit every value is stored in. The data layer sees an ordinary
  numeric column, so `sum`, `avg`, comparison, sorting, and filtering all work natively.

      attribute :delta_v, :unit do
        constraints base_unit: "meter-per-second"
      end

      attribute :dry_mass, :unit do
        constraints base_unit: "kilogram", storage: :decimal
      end

  ## Constraints

    * `:base_unit` (required) — a CLDR unit identifier (see
      [TR35](https://www.unicode.org/reports/tr35/tr35-general.html#unit-syntax)). It
      defines the dimension; every value is stored in this unit.
    * `:storage` — the numeric storage type: `:decimal` (default), `:float`, or
      `:integer`.
    * `:category` — an optional CLDR unit category (e.g. `"speed"`); when set, a
      supplied unit must belong to it. The per-category types set this for you.

  ## Casting

  `cast_input/2` accepts a bare number (taken to already be in the base unit), a
  `{value, unit}` tuple, a `%{value:, unit:}` map (atom or string keys), or a
  `%Localize.Unit{}`. A supplied unit must be dimensionally compatible with the base
  unit — `{5, "kilogram"}` into a speed attribute is rejected — and is converted to
  the base unit before storage.

  In Elixir the value is a `%Localize.Unit{}` quantity that knows its unit, so it can
  format itself (see `AshLocalize.Calculations.FormatUnit`) and convert via
  `Localize.Unit.convert/2`. In the data layer it is a plain number.
  """

  use Ash.Type

  @constraints [
    base_unit: [
      type: {:custom, __MODULE__, :validate_base_unit, []},
      required: true,
      doc: "The CLDR unit identifier every value is stored in; defines the dimension."
    ],
    storage: [
      type: {:in, [:decimal, :float, :integer]},
      default: :decimal,
      doc: "Numeric storage type for the underlying column."
    ],
    category: [
      type: {:custom, __MODULE__, :validate_category, []},
      required: false,
      doc: "Optional CLDR unit category; a supplied unit must belong to it when set."
    ]
  ]

  @impl true
  def constraints, do: @constraints

  @doc false
  # Custom `Spark.Options` validator for the `:base_unit` constraint: rejects anything
  # Localize does not recognise as a unit identifier, when the resource is compiled.
  def validate_base_unit(unit) when is_binary(unit) do
    case Localize.Unit.new(1, unit) do
      {:ok, _quantity} -> {:ok, unit}
      {:error, _reason} -> {:error, "is not a known CLDR unit identifier: #{inspect(unit)}"}
    end
  end

  def validate_base_unit(other) do
    {:error, "base_unit must be a string, got: #{inspect(other)}"}
  end

  @doc false
  # Custom `Spark.Options` validator for the `:category` constraint.
  def validate_category(category) when is_binary(category) do
    if category in known_categories() do
      {:ok, category}
    else
      {:error, "is not a known CLDR unit category: #{inspect(category)}"}
    end
  end

  def validate_category(other) do
    {:error, "category must be a string, got: #{inspect(other)}"}
  end

  defp known_categories do
    Enum.map(Localize.Unit.known_categories(), &to_string/1)
  end

  @impl true
  def storage_type(constraints), do: Keyword.get(constraints, :storage, :decimal)

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(%Localize.Unit{} = quantity, constraints) do
    cast_quantity(quantity, constraints)
  end

  def cast_input({value, unit}, constraints), do: cast_pair(value, unit, constraints)

  def cast_input(%{value: value, unit: unit}, constraints),
    do: cast_pair(value, unit, constraints)

  def cast_input(%{"value" => value, "unit" => unit}, constraints) do
    cast_pair(value, unit, constraints)
  end

  def cast_input(value, constraints) when is_number(value) or is_struct(value, Decimal) do
    cast_pair(value, base_unit(constraints), constraints)
  end

  def cast_input(_value, _constraints), do: {:error, message: "is not a valid quantity"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}

  def cast_stored(value, constraints) when is_number(value) or is_struct(value, Decimal) do
    case Localize.Unit.new(value, base_unit(constraints)) do
      {:ok, quantity} -> {:ok, quantity}
      {:error, _reason} -> :error
    end
  end

  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(%Localize.Unit{value: value}, _constraints), do: {:ok, value}
  def dump_to_native(_value, _constraints), do: :error

  defp cast_pair(value, unit, constraints) do
    case Localize.Unit.new(value, unit) do
      {:ok, quantity} -> cast_quantity(quantity, constraints)
      {:error, _reason} -> {:error, message: "is not a valid unit of measure"}
    end
  end

  defp cast_quantity(%Localize.Unit{value: %Decimal{coef: coef}}, _constraints)
       when coef in [:NaN, :inf],
       do: {:error, message: "is not a valid quantity"}

  defp cast_quantity(%Localize.Unit{} = quantity, constraints) do
    with :ok <- check_category(quantity, constraints) do
      to_base_unit(quantity, constraints)
    end
  end

  defp check_category(%Localize.Unit{} = quantity, constraints) do
    case Keyword.get(constraints, :category) do
      nil ->
        :ok

      category ->
        case Localize.Unit.unit_category(quantity) do
          {:ok, ^category} -> :ok
          _other -> {:error, message: "is not a valid #{category} measurement"}
        end
    end
  end

  defp to_base_unit(%Localize.Unit{} = quantity, constraints) do
    case Localize.Unit.convert(quantity, base_unit(constraints)) do
      {:ok, converted} ->
        {:ok, converted}

      {:error, _reason} ->
        {:error, message: "is not compatible with the attribute's base unit"}
    end
  end

  defp base_unit(constraints), do: Keyword.fetch!(constraints, :base_unit)
end
