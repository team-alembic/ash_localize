defmodule AshLocalize.Calculations.FormatOrdinal do
  @moduledoc """
  An Ash calculation that renders an integer attribute as a locale-correct ordinal —
  `1` → `"1st"` in English, `"1er"` in French, `"第1"` in Japanese — via Localize's
  RBNF support.

      calculate :rank_display, :string,
        {AshLocalize.Calculations.FormatOrdinal, field: :rank}

  ## Options

    * `:field` (required) — the integer attribute.
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
    Helpers.format(records, opts, context, fn n, locale, _record ->
      case Localize.Number.to_string(n, locale: locale, format: :ordinal) do
        {:ok, formatted} -> formatted
        {:error, reason} -> raise "AshLocalize could not format ordinal: #{inspect(reason)}"
      end
    end)
  end
end
