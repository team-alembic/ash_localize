defmodule AshLocalize.Calculations.FormatRatio do
  @moduledoc """
  An Ash calculation that renders a numeric ratio as a vulgar fraction string —
  `0.75` becomes `"3⁄4"`, `0.625` becomes `"5⁄8"` — via
  `Localize.Number.to_ratio_string/2`.

      calculate :completion_display, :string,
        {AshLocalize.Calculations.FormatRatio, field: :completion_ratio}

  ## Options

    * `:field` (required) — the numeric attribute (typically `AshLocalize.Types.Ratio`).
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
      case Localize.Number.to_ratio_string(value, locale: locale) do
        {:ok, formatted} -> formatted
        {:error, reason} -> raise "AshLocalize could not format ratio: #{inspect(reason)}"
      end
    end)
  end
end
