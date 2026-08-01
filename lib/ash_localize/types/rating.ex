defmodule AshLocalize.Types.Rating do
  @moduledoc """
  An `Ash.Type` for a user-facing rating on a known scale — `4.5` on a scale `:out_of`
  `5`, for example. Stored as a `Decimal`; rendered via
  `AshLocalize.Calculations.FormatRating`.

      attribute :rating, :rating, constraints: [out_of: 5, of: :stars]

  ## Constraints

    * `:out_of` (required) — the maximum of the scale (e.g. `5`).
    * `:of` — atom describing what is being rated (optional; used to drive the plural
      noun in `FormatRating`).
    * `:min` — minimum value (default `0.0`).
  """

  use AshLocalize.QuantityType,
    storage: :decimal,
    message: "is not a number",
    min: 0.0,
    max_key: :out_of,
    max_required?: true,
    constraints: [
      of: [type: :atom, required: false, doc: "What is being rated (e.g. `:stars`)."]
    ]
end
