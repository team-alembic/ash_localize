defmodule AshLocalize.Types.Count do
  @moduledoc """
  An `Ash.Type` for a count — a non-negative integer of *something*.

  The `:of` constraint tags what is being counted (e.g. `:comments`, `:retries`).
  That tag is metadata: it documents intent in the schema, drives pluralisation in
  `AshLocalize.Calculations.FormatCount`, and is the key the future translation
  catalogue (Phase 7) will use to look up locale-specific templates — including
  Japanese counter words.

      attribute :comment_count, :count, constraints: [of: :comments]
      attribute :retry_count, :count, constraints: [of: :retries, max: 10]

  Works seamlessly with Ash aggregates — the storage is `:integer`:

      aggregates do
        count :comment_count, :comments
      end

  ## Constraints

    * `:of` — atom describing what is being counted (optional but recommended).
    * `:min` — minimum value (default `0`).
    * `:max` — maximum value (optional, inclusive).
    * `:zero?` — whether zero is allowed (default `true`).
  """

  use Ash.Type

  @constraints [
    of: [
      type: :atom,
      required: false,
      doc: "What is being counted (e.g. `:comments`). The plural-template key."
    ],
    min: [type: :integer, default: 0, doc: "Minimum allowed value."],
    max: [type: :integer, required: false, doc: "Maximum allowed value (inclusive)."],
    zero?: [type: :boolean, default: true, doc: "Whether zero is an allowed value."]
  ]

  @impl true
  def constraints, do: @constraints

  @impl true
  def storage_type(_constraints), do: :integer

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}
  def cast_input(n, _constraints) when is_integer(n), do: {:ok, n}
  def cast_input(_value, _constraints), do: {:error, message: "is not an integer count"}

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
    case constraint_errors(n, constraints) do
      [] -> :ok
      [error] -> {:error, error}
      errors -> {:error, errors}
    end
  end

  defp constraint_errors(n, constraints) do
    []
    |> add_min_error(n, Keyword.get(constraints, :min, 0))
    |> add_max_error(n, Keyword.get(constraints, :max))
    |> add_zero_error(n, Keyword.get(constraints, :zero?, true))
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

  defp add_zero_error(errors, 0, false) do
    [[message: "must not be zero"] | errors]
  end

  defp add_zero_error(errors, _n, _zero?), do: errors
end
