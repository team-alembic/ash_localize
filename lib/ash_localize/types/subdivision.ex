defmodule AshLocalize.Types.Subdivision do
  @moduledoc """
  An `Ash.Type` for an ISO 3166-2 country-subdivision code (states, provinces,
  regions, counties), validated against CLDR via Localize.

  Stored as a lower-cased string — CLDR's canonical form — so it works on every
  Ash data layer. Casting normalises input to lowercase and rejects values CLDR
  does not recognise. `:caon` is Ontario, Canada; `:gbeng` is England;
  `:usca` is California.

  ## Constraints

    * `:territory` — restrict valid codes to subdivisions of the given territory
      (e.g. `territory: :CA`). The territory is itself validated via
      `Localize.validate_territory/1`.

  Referenced as `:subdivision` once the short type names are registered — see the
  README.
  """

  use AshLocalize.CodeType,
    message: "is not a valid subdivision",
    constraints: [
      territory: [
        type: {:or, [:atom, :string]},
        required: false,
        doc: "Restrict valid codes to subdivisions of this CLDR territory."
      ]
    ]

  alias Localize.Territory.Subdivision, as: LocalizeSubdivision

  @impl true
  def cast_code(value, constraints) do
    with {:ok, code} <- validate_code(value),
         :ok <- validate_territory(code, constraints[:territory]) do
      {:ok, Atom.to_string(code)}
    end
  end

  defp validate_code(value) do
    case Localize.validate_territory_subdivision(value) do
      {:ok, code} -> {:ok, code}
      {:error, _reason} -> code_error()
    end
  end

  defp validate_territory(_code, nil), do: :ok

  defp validate_territory(code, territory) do
    with {:ok, territory_code} <- Localize.validate_territory(territory),
         {:ok, codes} <- LocalizeSubdivision.for_territory(territory_code) do
      if code in codes do
        :ok
      else
        {:error,
         message: "is not a subdivision of %{territory}", territory: to_string(territory_code)}
      end
    else
      _ -> {:error, message: "is not a valid territory"}
    end
  end
end
