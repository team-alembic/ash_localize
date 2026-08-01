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

  use AshLocalize.QuantityType,
    storage: :decimal,
    message: "is not a number",
    constraints: [
      of: [type: :atom, required: false, doc: "What is being scored (e.g. `:priority`)."]
    ]
end
