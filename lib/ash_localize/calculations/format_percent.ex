defmodule AshLocalize.Calculations.FormatPercent do
  @moduledoc """
  An Ash calculation that renders a numeric attribute as a locale-formatted percentage
  via `Localize.Number.to_string/2` with `format: :percent`. `0.75` becomes `"75%"`.

      calculate :completion_display, :string,
        {AshLocalize.Calculations.FormatPercent, field: :completion}

  ## Options

    * `:field` (required) — the numeric attribute (typically `AshLocalize.Types.Percentage`).
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
      case Localize.Number.to_string(value, locale: locale, format: :percent) do
        {:ok, formatted} -> formatted
        {:error, reason} -> raise "AshLocalize could not format percentage: #{inspect(reason)}"
      end
    end)
  end
end
