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

  use AshLocalize.QuantityType,
    storage: :integer,
    message: "is not an integer count",
    min: 0,
    constraints: [
      of: [
        type: :atom,
        required: false,
        doc: "What is being counted (e.g. `:comments`). The plural-template key."
      ],
      zero?: [type: :boolean, default: true, doc: "Whether zero is an allowed value."]
    ]

  @impl true
  def extra_errors(0, constraints) do
    if Keyword.get(constraints, :zero?, true), do: [], else: [[message: "must not be zero"]]
  end

  def extra_errors(_value, _constraints), do: []
end
