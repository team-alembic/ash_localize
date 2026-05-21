defmodule AshLocalize.Types.Territory do
  @moduledoc """
  An `Ash.Type` for a CLDR-validated territory (region) code.

  Stored as an upper-cased string, so it works on every Ash data layer. Casting checks
  the value against CLDR's territory validity data via Localize and stores the canonical
  upper-cased form: `"us"` becomes `"US"`.

  Accepts both ISO 3166 alpha-2 codes and UN M.49 numeric region codes that CLDR
  recognises.

  Referenced as `:territory` once the short type names are registered — see the README.
  """

  use Ash.Type

  @impl true
  def storage_type(_constraints), do: :string

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(value, _constraints) when is_binary(value) do
    case Localize.validate_territory(value) do
      {:ok, code} -> {:ok, Atom.to_string(code)}
      {:error, _reason} -> {:error, message: "is not a valid territory"}
    end
  end

  def cast_input(_value, _constraints), do: {:error, message: "is not a valid territory"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(value, _constraints) when is_binary(value), do: {:ok, value}
  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(value, _constraints) when is_binary(value), do: {:ok, value}
  def dump_to_native(_value, _constraints), do: :error
end
