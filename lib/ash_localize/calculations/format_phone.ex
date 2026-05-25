if Code.ensure_loaded?(Localize.PhoneNumber) do
  defmodule AshLocalize.Calculations.FormatPhone do
    @moduledoc """
    An Ash calculation that renders an `AshLocalize.Types.PhoneNumber` attribute as a
    formatted string via `Localize.PhoneNumber.to_string/2`.

        calculations do
          calculate :contact_phone_display, :string,
            {AshLocalize.Calculations.FormatPhone, field: :contact_phone}
        end

    ## Options

      * `:field` (required) — the atom name of the `:phone_number` attribute.
      * `:format` — the style: `:international` (default), `:national`, `:e164`, or
        `:rfc3966`.

    Phone-number formatting is determined by the number's own country rather than a
    display locale, so this calculation takes no locale. A `nil` source value yields `nil`.

    Requires the optional `:localize_phone_number` dependency.
    """

    use Ash.Resource.Calculation

    alias AshLocalize.Calculations.Helpers

    @impl true
    def init(opts), do: Helpers.require_field(opts)

    @impl true
    def load(_query, opts, _context), do: [opts[:field]]

    @impl true
    def calculate(records, opts, _context) do
      style = Keyword.get(opts, :format, :international)
      Enum.map(records, &format_record(&1, opts[:field], style))
    end

    defp format_record(record, field, style) do
      case Map.get(record, field) do
        nil -> nil
        number -> format(number, style)
      end
    end

    defp format(number, style) do
      case Localize.PhoneNumber.to_string(number, style) do
        {:ok, formatted} -> formatted
        {:error, reason} -> raise "AshLocalize could not format a phone number: #{reason}"
      end
    end
  end
end
