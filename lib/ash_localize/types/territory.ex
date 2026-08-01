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

  use AshLocalize.CodeType, message: "is not a valid territory"

  @impl true
  def cast_code(value, _constraints) do
    case Localize.validate_territory(value) do
      {:ok, code} -> {:ok, Atom.to_string(code)}
      {:error, _reason} -> code_error()
    end
  end
end
