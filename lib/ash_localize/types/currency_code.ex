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

  use Ash.Type

  @impl true
  def storage_type(_constraints), do: :string

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(value, _constraints) when is_binary(value) do
    case Localize.Currency.validate_currency(value) do
      {:ok, code} -> {:ok, Atom.to_string(code)}
      {:error, _reason} -> {:error, message: "is not a valid currency code"}
    end
  end

  def cast_input(_value, _constraints), do: {:error, message: "is not a valid currency code"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(value, _constraints) when is_binary(value), do: {:ok, value}
  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(value, _constraints) when is_binary(value), do: {:ok, value}
  def dump_to_native(_value, _constraints), do: :error
end
