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

  use Ash.Type

  alias Localize.Territory.Subdivision, as: LocalizeSubdivision

  @constraints [
    territory: [
      type: {:or, [:atom, :string]},
      required: false,
      doc: "Restrict valid codes to subdivisions of this CLDR territory."
    ]
  ]

  @impl true
  def constraints, do: @constraints

  @impl true
  def storage_type(_constraints), do: :string

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(value, constraints) when is_atom(value) do
    value |> Atom.to_string() |> cast_input(constraints)
  end

  def cast_input(value, constraints) when is_binary(value) do
    with {:ok, code} <- validate_code(value),
         :ok <- validate_territory(code, constraints[:territory]) do
      {:ok, Atom.to_string(code)}
    end
  end

  def cast_input(_value, _constraints), do: {:error, message: "is not a valid subdivision"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(value, _constraints) when is_binary(value), do: {:ok, value}
  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(value, _constraints) when is_binary(value), do: {:ok, value}
  def dump_to_native(_value, _constraints), do: :error

  defp validate_code(value) do
    case Localize.validate_territory_subdivision(value) do
      {:ok, code} -> {:ok, code}
      {:error, _} -> {:error, message: "is not a valid subdivision"}
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
