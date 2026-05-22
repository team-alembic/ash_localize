defmodule AshLocalize.Calculations.FormatUnit do
  @moduledoc """
  An Ash calculation that renders an `AshLocalize.Types.Unit` attribute as a
  locale-formatted string.

  The attribute value is already a `%Localize.Unit{}` quantity carrying its unit, so
  this calculation only resolves the locale (through `AshLocalize.Context`) and renders
  — for example a `meter-per-second` quantity becomes `"7,800 meters per second"`.

      calculations do
        calculate :formatted_delta_v, :string,
          {AshLocalize.Calculations.FormatUnit, field: :delta_v}
      end

  ## Options

    * `:field` (required) — the atom name of the `:unit`-typed attribute to format.
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
    Helpers.format(records, opts, context, fn quantity, locale, _record ->
      Localize.Unit.to_string!(quantity, locale: locale)
    end)
  end
end
