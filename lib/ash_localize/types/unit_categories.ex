defmodule AshLocalize.Types.Unit.Category do
  @moduledoc false
  # `use`d by each generated per-category unit type. A category type is the
  # `AshLocalize.Types.Unit` engine pre-bound to a CLDR category and a default base
  # unit; every `Ash.Type` callback delegates to the engine with those injected.

  defmacro __using__(opts) do
    quote bind_quoted: [
            category: Keyword.fetch!(opts, :category),
            base_unit: Keyword.fetch!(opts, :base_unit)
          ] do
      use Ash.Type

      alias AshLocalize.Types.Unit, as: Engine

      @category category
      @default_base_unit base_unit

      @constraints [
        base_unit: [
          type: {:custom, Engine, :validate_base_unit, []},
          default: @default_base_unit,
          doc: "The CLDR unit values are stored in. Defaults to `#{@default_base_unit}`."
        ],
        storage: [
          type: {:in, [:decimal, :float, :integer]},
          default: :decimal,
          doc: "Numeric storage type for the underlying column."
        ]
      ]

      @impl true
      def constraints, do: @constraints

      @impl true
      def storage_type(constraints), do: Engine.storage_type(bind_category(constraints))

      @impl true
      def cast_input(value, constraints), do: Engine.cast_input(value, bind_category(constraints))

      @impl true
      def cast_stored(value, constraints),
        do: Engine.cast_stored(value, bind_category(constraints))

      @impl true
      def dump_to_native(value, constraints) do
        Engine.dump_to_native(value, bind_category(constraints))
      end

      # Inject this type's fixed category and default base unit before delegating, so
      # the type behaves correctly whether or not Ash has filled constraint defaults.
      defp bind_category(constraints) do
        constraints
        |> Keyword.put_new(:base_unit, @default_base_unit)
        |> Keyword.put(:category, @category)
      end
    end
  end
end

# The per-category unit types, generated from one spec list. Each entry is
# `{module suffix, CLDR category, default base unit, doc summary}`. Adding a category
# is a single line. `Duration` and `Concentration` are deliberately excluded — see
# the project notes.
for {name, category, base_unit, summary} <- [
      {Length, "length", "meter", "a length"},
      {Distance, "length", "meter", "a distance (an alias of `AshLocalize.Types.Length`)"},
      {Mass, "mass", "kilogram",
       "a mass — the quantity everyday language loosely calls *weight*. For weight as " <>
         "a physical force, use `AshLocalize.Types.Force`"},
      {Speed, "speed", "meter-per-second", "a speed or velocity"},
      {Acceleration, "acceleration", "meter-per-square-second", "an acceleration"},
      {Force, "force", "newton", "a force — including *weight* in the physical sense"},
      {Volume, "volume", "cubic-meter", "a volume"},
      {Area, "area", "square-meter", "an area"},
      {Temperature, "temperature", "kelvin", "a temperature"},
      {Energy, "energy", "joule", "an energy"},
      {Power, "power", "watt", "a power"},
      {Pressure, "pressure", "pascal", "a pressure"},
      {Angle, "angle", "radian", "an angle"},
      {Frequency, "frequency", "hertz", "a frequency"},
      {Digital, "digital", "byte", "a quantity of digital information"},
      {ElectricCurrent, "electric-current", "ampere", "an electric current"},
      {Voltage, "voltage", "volt", "a voltage"}
    ] do
  defmodule Module.concat(AshLocalize.Types, name) do
    @moduledoc """
    An `Ash.Type` for #{summary}.

    A category-bound `AshLocalize.Types.Unit`: values are CLDR-validated and restricted
    to the `#{category}` category, converted to the base unit, and stored as a plain
    number in the data layer. The default base unit is `#{base_unit}` — override it per
    attribute with the `:base_unit` constraint.
    """

    use AshLocalize.Types.Unit.Category, category: category, base_unit: base_unit
  end
end
