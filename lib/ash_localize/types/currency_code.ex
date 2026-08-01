defmodule AshLocalize.Types.CurrencyCode do
  @moduledoc """
  An `Ash.Type` for a CLDR-validated [ISO 4217](https://www.iso.org/iso-4217-currency-codes.html)
  currency code.

  Stored as an upper-cased string, so it works on every Ash data layer. Casting checks
  the value against CLDR's currency data via Localize and stores the canonical
  upper-cased form: `"aud"` becomes `"AUD"`.

  This type carries only the code. A money amount paired with its currency is the
  separate `Currency` type, planned for a later phase.

  Referenced as `:currency_code` once the short type names are registered — see the README.
  """

  use AshLocalize.CodeType, message: "is not a valid currency code"

  @impl true
  def cast_code(value, _constraints) do
    case Localize.Currency.validate_currency(value) do
      {:ok, code} -> {:ok, Atom.to_string(code)}
      {:error, _reason} -> code_error()
    end
  end
end
