defmodule AshLocalize.Types.Ratio do
  @moduledoc """
  An `Ash.Type` for a ratio — a `Decimal` between 0 and 1, rendered as a vulgar
  fraction (`"3⁄4"`) by `AshLocalize.Calculations.FormatRatio`.

      attribute :completion_ratio, :ratio

  ## Constraints

    * `:min` — minimum value (default `0.0`).
    * `:max` — maximum value (default `1.0`).
  """

  use Ash.Type

  @constraints [
    min: [type: {:or, [:float, :integer]}, default: 0.0, doc: "Minimum allowed value."],
    max: [type: {:or, [:float, :integer]}, default: 1.0, doc: "Maximum allowed value."]
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
    min = constraints |> Keyword.get(:min, 0.0) |> to_decimal()
    max = constraints |> Keyword.get(:max, 1.0) |> to_decimal()

    errors =
      []
      |> maybe_add(Decimal.lt?(d, min), message: "must be at least %{min}", min: min)
      |> maybe_add(Decimal.gt?(d, max), message: "must be at most %{max}", max: max)

    case errors do
      [] -> :ok
      [error] -> {:error, error}
      errors -> {:error, errors}
    end
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)

  defp maybe_add(errors, true, error), do: [error | errors]
  defp maybe_add(errors, false, _error), do: errors
end
