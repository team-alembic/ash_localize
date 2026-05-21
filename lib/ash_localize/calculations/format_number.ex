defmodule AshLocalize.Calculations.FormatNumber do
  @moduledoc """
  An Ash calculation that renders a numeric attribute as a locale-formatted string.

  The locale is resolved through `AshLocalize.Context` — see that module for the
  resolution chain. Add a `:locale` argument to the calculation to enable the explicit
  argument arm.

      calculations do
        calculate :formatted_quantity, :string,
          {AshLocalize.Calculations.FormatNumber, field: :quantity}
      end

  ## Options

    * `:field` (required) — the atom name of the numeric (`integer`/`decimal`/`float`)
      attribute to format.
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
      Localize.Number.to_string!(value, locale: locale)
    end)
  end
end
