if Code.ensure_loaded?(Localize.PersonName) do
  defmodule AshLocalize.Calculations.FormatPersonName do
    @moduledoc """
    An Ash calculation that renders an `AshLocalize.Types.PersonName` attribute as a
    locale-formatted string via `Localize.PersonName.to_string!/2`.

        calculations do
          calculate :author_display, :string,
            {AshLocalize.Calculations.FormatPersonName, field: :author_name}
        end

    ## Options

      * `:field` (required) — the atom name of the `:person_name` attribute.
      * `:format`, `:usage`, `:formality`, `:order` — optional, passed through to
        `Localize.PersonName.to_string/2` (e.g. `usage: :referring` for `"Ada Lovelace"`
        rather than the addressing default `"Ada"`).
      * `:actor_locale` — an actor-locale extractor, as for `AshLocalize.Context.locale/2`.

    A `nil` source value produces a `nil` result.

    Requires the optional `:localize_person_names` dependency.
    """

    use Ash.Resource.Calculation

    alias AshLocalize.Calculations.Helpers

    @format_options [:format, :usage, :formality, :order]

    @impl true
    def init(opts), do: Helpers.require_field(opts)

    @impl true
    def load(_query, opts, _context), do: [opts[:field]]

    @impl true
    def calculate(records, opts, context) do
      format_options = Keyword.take(opts, @format_options)

      Helpers.format(records, opts, context, fn name, locale, _record ->
        Localize.PersonName.to_string!(name, [{:locale, locale} | format_options])
      end)
    end
  end
end
