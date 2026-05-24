defmodule AshLocalize.Types.Score do
  @moduledoc """
  An `Ash.Type` for a domain-defined score — a `Decimal` with optional bounds.

  Use it for any unbounded-by-default numeric quantity that *is* a score (priority,
  ranking signal, machine-learning output). Render via
  `AshLocalize.Calculations.FormatScore` for locale-correct decimal separators.

      attribute :priority_score, :score, constraints: [min: 0, max: 100]

  ## Constraints

    * `:of` — atom describing what is being scored (optional).
    * `:min` — minimum value (optional).
    * `:max` — maximum value (optional).
  """

  use Ash.Type

  @constraints [
    of: [type: :atom, required: false, doc: "What is being scored (e.g. `:priority`)."],
    min: [type: {:or, [:float, :integer]}, required: false, doc: "Minimum allowed value."],
    max: [type: {:or, [:float, :integer]}, required: false, doc: "Maximum allowed value."]
  ]

  @impl true
  def constraints, do: @constraints

  @impl true
  def storage_type(_constraints), do: :decimal

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}
  def cast_input(%Decimal{} = d, _constraints), do: {:ok, d}
  def cast_input(n, _constraints) when is_integer(n), do: {:ok, Decimal.new(n)}
  def cast_input(n, _constraints) when is_float(n), do: {:ok, Decimal.from_float(n)}
  def cast_input(_value, _constraints), do: {:error, message: "is not a number"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(%Decimal{} = d, _constraints), do: {:ok, d}
  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(%Decimal{} = d, _constraints), do: {:ok, d}
  def dump_to_native(_value, _constraints), do: :error

  @impl true
  def apply_constraints(nil, _constraints), do: :ok

  def apply_constraints(%Decimal{} = d, constraints) do
    errors =
      []
      |> bound_error(d, Keyword.get(constraints, :min), :min)
      |> bound_error(d, Keyword.get(constraints, :max), :max)

    case errors do
      [] -> :ok
      [error] -> {:error, error}
      errors -> {:error, errors}
    end
  end

  defp bound_error(errors, _d, nil, _kind), do: errors

  defp bound_error(errors, d, bound, :min) do
    bound = to_decimal(bound)

    if Decimal.lt?(d, bound),
      do: [[message: "must be at least %{min}", min: bound] | errors],
      else: errors
  end

  defp bound_error(errors, d, bound, :max) do
    bound = to_decimal(bound)

    if Decimal.gt?(d, bound),
      do: [[message: "must be at most %{max}", max: bound] | errors],
      else: errors
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)
end
