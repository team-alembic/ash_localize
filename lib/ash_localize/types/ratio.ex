defmodule AshLocalize.Types.Ratio do
  @moduledoc """
  An `Ash.Type` for a ratio — a `Decimal` between 0 and 1, rendered as a vulgar
  fraction (`"3⁄4"`) by `AshLocalize.Calculations.FormatRatio`.

      attribute :completion_ratio, :ratio

  ## Constraints

    * `:min` — minimum value (default `0.0`).
    * `:max` — maximum value (default `1.0`).
  """

  use AshLocalize.QuantityType,
    storage: :decimal,
    message: "is not a number",
    min: 0.0,
    max: 1.0
end
