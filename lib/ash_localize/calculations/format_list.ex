defmodule AshLocalize.Calculations.FormatList do
  @moduledoc """
  An Ash calculation that joins a list attribute into a locale-formatted string.

  Uses the locale's conjunction patterns — for example `["a", "b", "c"]` renders as
  `"a, b, and c"` in English. The locale is resolved through `AshLocalize.Context`.

      calculations do
        calculate :formatted_tags, :string,
          {AshLocalize.Calculations.FormatList, field: :tags}
      end

  ## Options

    * `:field` (required) — the atom name of the list attribute to format.
    * `:actor_locale` — an actor-locale extractor, as for `AshLocalize.Context.locale/2`.

  A `nil` source value produces a `nil` result; an empty list produces an empty string.
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
      Localize.List.to_string!(value, locale: locale)
    end)
  end
end
