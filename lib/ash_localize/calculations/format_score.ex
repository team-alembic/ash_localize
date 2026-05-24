defmodule AshLocalize.Calculations.FormatScore do
  @moduledoc """
  An Ash calculation that renders a numeric score with locale-correct decimal
  separators and grouping via `Localize.Number.to_string/2`.

      calculate :priority_score_display, :string,
        {AshLocalize.Calculations.FormatScore, field: :priority_score}

  ## Options

    * `:field` (required) — the numeric attribute (typically `AshLocalize.Types.Score`).
    * `:actor_locale` — an actor-locale extractor, as for `AshLocalize.Context.locale/2`.

  A `nil` source value produces a `nil` result.
  """

  use Ash.Resource.Calculation

  alias AshLocalize.Calculations.Helpers

  @impl true
  def init(opts), do: Helpers.require_field(opts)

  @impl true
  def load(_query, opts, _context), do: [opts[:field]]

  @impl true
  def calculate(records, opts, context) do
    Helpers.format(records, opts, context, fn value, locale, _record ->
      case Localize.Number.to_string(value, locale: locale) do
        {:ok, formatted} -> formatted
        {:error, reason} -> raise "AshLocalize could not format score: #{inspect(reason)}"
      end
    end)
  end
end
