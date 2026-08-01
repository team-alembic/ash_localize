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

  use AshLocalize.QuantityType,
    storage: :integer,
    message: "is not an integer ordinal",
    min: 1,
    constraints: [
      of: [
        type: :atom,
        required: false,
        doc: "What is being ranked (e.g. `:leaderboard_rank`). The plural-template key."
      ]
    ]
end
