defmodule AshLocalize.Types.PhoneNumber do
  @moduledoc """
  An `Ash.Type` for a phone number, parsed and validated via Localize (libphonenumber).

  Stored as an E.164 string; the loaded value is a `%Localize.PhoneNumber.Number{}` that
  renders itself — see `AshLocalize.Calculations.FormatPhone`.

      attribute :contact_phone, :phone_number

  Casting parses the input and rejects numbers that are unparseable or invalid. Supply
  numbers in E.164 form (`"+1 650-253-0000"`) for reliable parsing.

  Requires the optional `:localize_phone_number` dependency.
  """

  use Ash.Type

  @impl true
  def storage_type(_constraints), do: :string

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}
  def cast_input(%Localize.PhoneNumber.Number{} = number, _constraints), do: {:ok, number}

  def cast_input(value, _constraints) when is_binary(value) do
    with {:ok, number} <- Localize.PhoneNumber.parse(value),
         true <- Localize.PhoneNumber.valid?(number) do
      {:ok, number}
    else
      _not_valid -> {:error, message: "is not a valid phone number"}
    end
  end

  def cast_input(_value, _constraints), do: {:error, message: "is not a valid phone number"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}

  def cast_stored(value, _constraints) when is_binary(value) do
    case Localize.PhoneNumber.parse(value) do
      {:ok, number} -> {:ok, number}
      {:error, _reason} -> :error
    end
  end

  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}

  def dump_to_native(%Localize.PhoneNumber.Number{} = number, _constraints) do
    case Localize.PhoneNumber.to_string(number, :e164) do
      {:ok, e164} -> {:ok, e164}
      {:error, _reason} -> :error
    end
  end

  def dump_to_native(_value, _constraints), do: :error
end
