defmodule AshLocalize.Types.PostalAddress do
  @moduledoc """
  An `Ash.Type` for a postal address, CLDR-aware via Localize.

  Stored as a map of address components; the loaded value is a
  `%Localize.Address.Address{}` struct that renders itself locale-appropriately — see
  `AshLocalize.Calculations.FormatAddress`.

      attribute :shipping_address, :postal_address

  Casting accepts a map of address components with atom or string keys, or an existing
  `%Localize.Address.Address{}`.

  ## Components

  `:attention`, `:house`, `:house_number`, `:road`, `:neighbourhood`, `:city`,
  `:municipality`, `:county`, `:state_district`, `:state`, `:postcode`, `:territory`,
  `:territory_code`, `:island`, `:archipelago`, `:continent`, `:raw_input`.

  Requires the optional `:localize_address` dependency.
  """

  use Ash.Type

  @fields ~w(attention house house_number road neighbourhood city municipality county
             state_district state postcode territory territory_code island archipelago
             continent raw_input)a

  @impl true
  def storage_type(_constraints), do: :map

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}
  def cast_input(%Localize.Address.Address{} = address, _constraints), do: {:ok, address}

  def cast_input(map, _constraints) when is_map(map) do
    case address_parts(map) do
      [] -> {:error, message: "is not a valid postal address"}
      parts -> {:ok, struct(Localize.Address.Address, parts)}
    end
  end

  def cast_input(_value, _constraints), do: {:error, message: "is not a valid postal address"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}

  def cast_stored(map, _constraints) when is_map(map) do
    {:ok, struct(Localize.Address.Address, address_parts(map))}
  end

  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}

  def dump_to_native(%Localize.Address.Address{} = address, _constraints) do
    {:ok, Map.from_struct(address)}
  end

  def dump_to_native(_value, _constraints), do: :error

  # Collect the known address-component fields from a map with atom or string keys.
  defp address_parts(map) do
    Enum.flat_map(@fields, fn field ->
      case fetch(map, field) do
        {:ok, value} -> [{field, value}]
        :error -> []
      end
    end)
  end

  defp fetch(map, field) do
    case Map.fetch(map, field) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(map, Atom.to_string(field))
    end
  end
end
