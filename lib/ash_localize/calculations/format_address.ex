if Code.ensure_loaded?(Localize.Address) do
  defmodule AshLocalize.Calculations.FormatAddress do
    @moduledoc """
    An Ash calculation that renders an `AshLocalize.Types.PostalAddress` attribute as a
    locale-formatted, multi-line string via `Localize.Address.to_string/2`.

        calculations do
          calculate :shipping_label, :string,
            {AshLocalize.Calculations.FormatAddress, field: :shipping_address}
        end

    ## Options

      * `:field` (required) — the atom name of the `:postal_address` attribute.
      * `:actor_locale` — an actor-locale extractor, as for `AshLocalize.Context.locale/2`.

    A `nil` source value produces a `nil` result.

    Requires the optional `:localize_address` dependency.
    """

    use Ash.Resource.Calculation

    alias AshLocalize.Calculations.Helpers

    @impl true
    def init(opts), do: Helpers.require_field(opts)

    @impl true
    def load(_query, opts, _context), do: [opts[:field]]

    @impl true
    def calculate(records, opts, context) do
      Helpers.format(records, opts, context, fn address, locale, _record ->
        case Localize.Address.to_string(address, locale: locale) do
          {:ok, formatted} -> formatted
          {:error, reason} -> raise "AshLocalize could not format an address: #{reason}"
        end
      end)
    end
  end
end
