defmodule AshLocalize.QuantityType do
  @moduledoc """
  Defines an `Ash.Type` for a dimensionless quantity that carries meaning.

  A *quantity* is a magnitude: it can be ordered, compared and aggregated. These are
  dimensionless ones — a count, a rank, a percentage, a rating. Attaching a dimension
  makes it an `AshLocalize.UnitType` instead; having no magnitude at all makes it an
  `AshLocalize.CodeType`.

  The point of a quantity type is that a bare `:integer` or `:decimal` stores the
  number and discards what it *means*. `:count` with `of: :comments` keeps both,
  which is what lets `AshLocalize.Calculations.FormatCount` pluralise it correctly.

  Storage stays a plain number, so `sum`, `avg`, sorting and filtering run natively
  on every data layer.

  ## Defining one

      defmodule MyApp.Types.Probability do
        use AshLocalize.QuantityType,
          storage: :decimal,
          message: "is not a number",
          min: 0.0,
          max: 1.0
      end

  That is the whole type. Casting, bound checking and the error shapes come from the
  macro.

  ## Options

    * `:storage` (required) — `:integer` or `:decimal`. Decides what casting accepts
      and what the column holds.
    * `:message` (required) — the cast error for a non-numeric value.
    * `:min` — default lower bound, or `nil` for unbounded. Defaults to `nil`.
    * `:max` — default upper bound, or `nil` for unbounded. Defaults to `nil`.
    * `:max_key` — the constraint holding the upper bound. Defaults to `:max`.
      `AshLocalize.Types.Rating` uses `:out_of`, so its error reads *must be at most
      %{out_of}* and the constraint is named for the domain rather than the mechanism.
    * `:max_required?` — whether the upper-bound constraint is mandatory. Defaults to
      `false`.
    * `:constraints` — extra `Spark.Options` definitions merged with the generated
      bounds.

  ## Extra validation

  Override `c:extra_errors/2` for checks the bounds cannot express. It returns a list
  of error keyword lists, which the macro merges with any bound errors so a value
  failing two rules reports both:

      @impl true
      def extra_errors(0, constraints) do
        if Keyword.get(constraints, :zero?, true), do: [], else: [[message: "must not be zero"]]
      end

      def extra_errors(_value, _constraints), do: []
  """

  @doc """
  Additional constraint errors for `value`. Defaults to `[]`.
  """
  @callback extra_errors(value :: term(), constraints :: Keyword.t()) :: [Keyword.t()]

  defmacro __using__(opts) do
    quote bind_quoted: [
            storage: Keyword.fetch!(opts, :storage),
            message: Keyword.fetch!(opts, :message),
            min_default: Keyword.get(opts, :min),
            max_default: Keyword.get(opts, :max),
            max_key: Keyword.get(opts, :max_key, :max),
            max_required?: Keyword.get(opts, :max_required?, false),
            extra_constraints: Keyword.get(opts, :constraints, [])
          ] do
      use Ash.Type

      @behaviour AshLocalize.QuantityType

      @storage storage
      @invalid_message message
      @min_default min_default
      @max_default max_default
      @max_key max_key

      bound_type = if storage == :integer, do: :integer, else: {:or, [:float, :integer]}

      min_spec =
        [type: {:or, [bound_type, nil]}, doc: "Minimum allowed value."] ++
          if(min_default, do: [default: min_default], else: [required: false])

      max_spec =
        [
          type: if(max_required?, do: bound_type, else: {:or, [bound_type, nil]}),
          doc: "Maximum allowed value (inclusive)."
        ] ++
          cond do
            max_required? -> [required: true]
            max_default -> [default: max_default]
            true -> [required: false]
          end

      @constraints [{:min, min_spec}, {max_key, max_spec}] ++ extra_constraints

      @impl Ash.Type
      def constraints, do: @constraints

      @impl Ash.Type
      def storage_type(_constraints), do: @storage

      @impl AshLocalize.QuantityType
      def extra_errors(_value, _constraints), do: []

      @impl Ash.Type
      def cast_input(nil, _constraints), do: {:ok, nil}

      @impl Ash.Type
      def cast_stored(nil, _constraints), do: {:ok, nil}

      @impl Ash.Type
      def dump_to_native(nil, _constraints), do: {:ok, nil}

      if storage == :integer do
        def cast_input(n, _constraints) when is_integer(n), do: {:ok, n}
        def cast_input(_value, _constraints), do: {:error, message: @invalid_message}

        def cast_stored(n, _constraints) when is_integer(n), do: {:ok, n}
        def cast_stored(_value, _constraints), do: :error

        def dump_to_native(n, _constraints) when is_integer(n), do: {:ok, n}
        def dump_to_native(_value, _constraints), do: :error

        defp compare_lt?(a, b), do: a < b
        defp compare_gt?(a, b), do: a > b
        defp coerce_bound(n), do: n
      else
        def cast_input(%Decimal{coef: coef}, _constraints) when coef in [:NaN, :inf],
          do: {:error, message: @invalid_message}

        def cast_input(%Decimal{} = d, _constraints), do: {:ok, d}
        def cast_input(n, _constraints) when is_integer(n), do: {:ok, Decimal.new(n)}
        def cast_input(n, _constraints) when is_float(n), do: {:ok, Decimal.from_float(n)}
        def cast_input(_value, _constraints), do: {:error, message: @invalid_message}

        def cast_stored(%Decimal{} = d, _constraints), do: {:ok, d}
        def cast_stored(_value, _constraints), do: :error

        def dump_to_native(%Decimal{} = d, _constraints), do: {:ok, d}
        def dump_to_native(_value, _constraints), do: :error

        defp compare_lt?(a, b), do: Decimal.lt?(a, b)
        defp compare_gt?(a, b), do: Decimal.gt?(a, b)
        defp coerce_bound(%Decimal{} = d), do: d
        defp coerce_bound(n) when is_integer(n), do: Decimal.new(n)
        defp coerce_bound(n) when is_float(n), do: Decimal.from_float(n)
      end

      @impl Ash.Type
      def apply_constraints(nil, _constraints), do: :ok

      def apply_constraints(value, constraints) do
        errors =
          bound_errors(value, constraints) ++ extra_errors(value, constraints)

        case errors do
          [] -> :ok
          [error] -> {:error, error}
          errors -> {:error, errors}
        end
      end

      defp bound_errors(value, constraints) do
        min = fetch_bound(constraints, :min, @min_default)
        max = fetch_bound(constraints, @max_key, @max_default)

        []
        |> add_bound_error(min && compare_lt?(value, min),
          message: "must be at least %{min}",
          min: min
        )
        |> add_bound_error(
          max && compare_gt?(value, max),
          [{:message, "must be at most %{#{@max_key}}"}, {@max_key, max}]
        )
      end

      defp fetch_bound(constraints, key, default) do
        case Keyword.get(constraints, key, default) do
          nil -> nil
          bound -> coerce_bound(bound)
        end
      end

      defp add_bound_error(errors, true, error), do: [error | errors]
      defp add_bound_error(errors, _falsy, _error), do: errors

      defoverridable extra_errors: 2, cast_input: 2, constraints: 0
    end
  end
end
