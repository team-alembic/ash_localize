defmodule AshLocalize.UnitType do
  @moduledoc """
  Defines a dimensioned-number Ash type bound to a CLDR base unit.

  Each type generated with this macro is the `AshLocalize.Types.Unit` engine pre-bound
  to a base unit — values are stored as a plain number in that unit, the loaded value
  is a `%Localize.Unit{}` quantity, and the data layer sees an ordinary numeric column.
  The 16 built-in per-category types (`AshLocalize.Types.Speed`, `Mass`, `Length`, …)
  are generated with this macro; the same machinery is available for custom types.

  ## Compound units (no setup needed)

  CLDR composes unit identifiers from primitives via `-per-`, `square-`, `cubic-`, and
  so on. Many domain-specific quantities are already expressible — *jerk* is
  `meter-per-cubic-second`, *angular acceleration* is `radian-per-square-second`,
  *fuel consumption* is `liter-per-100-kilometer`. Localize parses and converts them
  out of the box; you do not need to register them anywhere.

  ## Defining a reusable type

      defmodule MyApp.Units.Jerk do
        use AshLocalize.UnitType, base_unit: "meter-per-cubic-second"
      end

  Or, for multiple custom units, the `defunit/2` one-liner:

      import AshLocalize.UnitType

      defunit MyApp.Units.Jerk, base_unit: "meter-per-cubic-second"
      defunit MyApp.Units.SpecificImpulse, base_unit: "meter-per-second"

  Then register and use as any built-in:

      # config/config.exs
      config :ash, :custom_types, jerk: MyApp.Units.Jerk

      # in a resource
      attribute :j, :jerk
      attribute :j, :jerk, constraints: [base_unit: "foot-per-cubic-second"]

  ## Options

    * `:base_unit` (required) — a CLDR unit identifier; the default `base_unit` for the
      generated type.
    * `:category` (optional) — a CLDR unit category (e.g. `"speed"`). When set, a
      supplied unit must belong to it — a stronger guard than dimensional compatibility,
      distinguishing same-dimension categories such as frequency vs. radioactivity.
      When omitted, the type accepts any unit dimensionally compatible with the
      base unit. This is the right mode for compound units with no CLDR category,
      like *jerk*.

  ## Genuinely custom named units

  A unit that is *not* expressible as a CLDR compound — your own named unit with custom
  conversion factors — is registered with `Localize.Unit.CustomRegistry.register/2`.
  Once registered, `ash_localize`'s type machinery accepts it without further changes:
  `validate_base_unit` and casting both route through `Localize.Unit`, which then
  knows the name.

  See the [Custom units](custom_units.html) guide for worked examples.
  """

  @doc """
  A one-line shortcut for defining a custom unit type.

      import AshLocalize.UnitType

      defunit MyApp.Units.Jerk, base_unit: "meter-per-cubic-second"
      defunit MyApp.Units.RadialAcceleration, base_unit: "meter-per-square-second"

  Expands to `defmodule <name> do use AshLocalize.UnitType, <opts> end`. Accepts the
  same options as `use AshLocalize.UnitType` — `:base_unit` (required), `:category`
  (optional).
  """
  defmacro defunit(name, opts) do
    quote do
      defmodule unquote(name) do
        use AshLocalize.UnitType, unquote(opts)
      end
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [
            category: Keyword.get(opts, :category),
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
      def storage_type(constraints), do: Engine.storage_type(bound_constraints(constraints))

      @impl true
      def cast_input(value, constraints) do
        Engine.cast_input(value, bound_constraints(constraints))
      end

      @impl true
      def cast_stored(value, constraints) do
        Engine.cast_stored(value, bound_constraints(constraints))
      end

      @impl true
      def dump_to_native(value, constraints) do
        Engine.dump_to_native(value, bound_constraints(constraints))
      end

      # Inject this type's fixed category and default base unit before delegating, so
      # the type behaves correctly whether or not Ash has filled constraint defaults.
      # A nil `:category` is omitted — the engine then relies on dimensional
      # compatibility alone, which is the right behaviour for compound units that
      # CLDR does not categorise (e.g. *jerk*).
      defp bound_constraints(constraints) do
        constraints = Keyword.put_new(constraints, :base_unit, @default_base_unit)

        if @category do
          Keyword.put(constraints, :category, @category)
        else
          constraints
        end
      end
    end
  end
end
