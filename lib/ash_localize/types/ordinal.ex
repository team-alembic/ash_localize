defmodule AshLocalize.Types.Ordinal do
  @moduledoc """
  An `Ash.Type` for an ordinal — a positive integer denoting position or rank.

  Use it for ranks and positions where the *order* is human-facing. Render via
  `AshLocalize.Calculations.FormatOrdinal` for locale-correct text — `"1st"` in
  English, `"1er"` in French, `"第1"` in Japanese.

      attribute :rank, :ordinal, constraints: [of: :leaderboard_rank, min: 1]

  ## Constraints

    * `:of` — atom describing what is being ranked (optional).
    * `:min` — minimum value (default `1`; ordinals start at 1).
    * `:max` — maximum value (optional, inclusive).
  """

  use Ash.Type

  @constraints [
    of: [
      type: :atom,
      required: false,
      doc: "What is being ranked (e.g. `:leaderboard_rank`). The plural-template key."
    ],
    min: [type: :integer, default: 1, doc: "Minimum allowed value."],
    max: [type: :integer, required: false, doc: "Maximum allowed value (inclusive)."]
  ]

  @impl true
  def constraints, do: @constraints

  @impl true
  def storage_type(_constraints), do: :integer

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}
  def cast_input(n, _constraints) when is_integer(n), do: {:ok, n}
  def cast_input(_value, _constraints), do: {:error, message: "is not an integer ordinal"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(n, _constraints) when is_integer(n), do: {:ok, n}
  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(n, _constraints) when is_integer(n), do: {:ok, n}
  def dump_to_native(_value, _constraints), do: :error

  @impl true
  def apply_constraints(nil, _constraints), do: :ok

  def apply_constraints(n, constraints) when is_integer(n) do
    min = Keyword.get(constraints, :min, 1)
    max = Keyword.get(constraints, :max)

    errors =
      []
      |> add_min_error(n, min)
      |> add_max_error(n, max)

    case errors do
      [] -> :ok
      [error] -> {:error, error}
      errors -> {:error, errors}
    end
  end

  defp add_min_error(errors, n, min) when n < min do
    [[message: "must be at least %{min}", min: min] | errors]
  end

  defp add_min_error(errors, _n, _min), do: errors

  defp add_max_error(errors, _n, nil), do: errors

  defp add_max_error(errors, n, max) when n > max do
    [[message: "must be at most %{max}", max: max] | errors]
  end

  defp add_max_error(errors, _n, _max), do: errors
end
