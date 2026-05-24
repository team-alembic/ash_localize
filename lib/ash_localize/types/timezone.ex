defmodule AshLocalize.Types.Timezone do
  @moduledoc """
  An `Ash.Type` for an IANA timezone name, validated against CLDR's timezone data
  via Localize.

  Stored as the canonical IANA name (the first alias of the BCP 47 short zone) so
  it plays well with `DateTime.shift_zone/2`, tzdata, Postgres `timestamptz`, and
  every other tool that speaks IANA — works on every Ash data layer.

  Casting accepts:

    * a canonical IANA name (`"Australia/Sydney"`) — passes through;
    * any IANA alias (`"Australia/ACT"`) — canonicalised to the preferred name;
    * a BCP 47 short zone (`"ausyd"`, `"utc"`) — canonicalised to IANA.

  Unknown names are rejected.

  Referenced as `:timezone` once the short type names are registered — see the README.
  """

  use Ash.Type

  alias Localize.DateTime.Timezone, as: LocalizeTimezone

  # Precomputed IANA-name → BCP 47 short-zone map. Walking
  # `Localize.DateTime.Timezone.timezones/0` once at compile time avoids the
  # 555-entry lookup on every cast. Each short zone's `aliases` covers every
  # IANA name CLDR knows for it; the value points back at the short zone so
  # we can route through `validate_short_zone/1` for canonicalisation.
  @iana_to_short for {short, %{aliases: aliases}} <- LocalizeTimezone.timezones(),
                     is_list(aliases),
                     iana <- aliases,
                     into: %{},
                     do: {iana, short}

  @impl true
  def storage_type(_constraints), do: :string

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(value, _constraints) when is_binary(value) do
    with :error <- as_short_zone(value),
         :error <- as_iana_name(value) do
      {:error, message: "is not a known timezone"}
    end
  end

  def cast_input(_value, _constraints), do: {:error, message: "is not a known timezone"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(value, _constraints) when is_binary(value), do: {:ok, value}
  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(value, _constraints) when is_binary(value), do: {:ok, value}
  def dump_to_native(_value, _constraints), do: :error

  defp as_short_zone(value) do
    case LocalizeTimezone.validate_short_zone(value) do
      {:ok, iana} -> {:ok, iana}
      {:error, _} -> :error
    end
  end

  defp as_iana_name(value) do
    case Map.fetch(@iana_to_short, value) do
      {:ok, short} -> as_short_zone(short)
      :error -> :error
    end
  end
end
