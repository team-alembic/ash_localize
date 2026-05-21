defmodule AshLocalize.Calculations.FormatDate do
  @moduledoc """
  An Ash calculation that renders a `Date` attribute as a locale-formatted string.

  The locale is resolved through `AshLocalize.Context` — see that module for the
  resolution chain.

      calculations do
        calculate :formatted_event_date, :string,
          {AshLocalize.Calculations.FormatDate, field: :event_date}
      end

  ## Options

    * `:field` (required) — the atom name of the `date` attribute to format.
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
      Localize.Date.to_string!(value, locale: locale)
    end)
  end
end
