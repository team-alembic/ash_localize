defmodule AshLocalize.Types.Percentage do
  @moduledoc """
  An `Ash.Type` for a percentage — a `Decimal` stored as a fraction of 1.

  Store `0.75` and render `"75%"` via `AshLocalize.Calculations.FormatPercent`. Bounded
  `0..1` by default; set `:max` higher (or to a huge value) for unbounded percentages.

      attribute :completion, :percentage
      attribute :load_factor, :percentage, constraints: [max: 1.5]

  ## Constraints

    * `:min` — minimum value (default `0.0`).
    * `:max` — maximum value (default `1.0`, inclusive).
  """

  use AshLocalize.QuantityType,
    storage: :decimal,
    message: "is not a number",
    min: 0.0,
    max: 1.0
end
