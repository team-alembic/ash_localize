defprotocol AshLocalize.Format do
  @moduledoc """
  Value-dispatched locale-aware formatting.

  The protocol every `AshLocalize.format/1,2` call dispatches through. The library's
  stance is that values carry their dimension — a `%Money{}` knows its currency, a
  `Localize.Unit` knows its base unit, a `%Date{}` is structurally identifiable — so
  formatting only needs the value itself, not the resource and an attribute name.

  Add an implementation for a custom value type to make it formattable:

      defimpl AshLocalize.Format, for: MyApp.Types.SomeStruct do
        def format(value, opts) do
          locale = AshLocalize.Context.locale!(%{}, argument: opts[:locale])
          # ... call into the upstream renderer, return a string
        end
      end
  """

  @doc """
  Formats `value` to a string. See `AshLocalize.format/2` for the public entry point.

  Implementations must accept `opts` as a keyword list. Conventional options:

    * `:locale` — explicit locale (highest-precedence arm of resolution).
    * Format-specific keys passed through to the upstream renderer.
  """
  @fallback_to_any false
  @spec format(t, keyword()) :: String.t()
  def format(value, opts)
end

defimpl AshLocalize.Format, for: Integer do
  alias AshLocalize.Context

  def format(n, opts) do
    Localize.Number.to_string!(n, locale: Context.locale!(%{}, argument: opts[:locale]))
  end
end

defimpl AshLocalize.Format, for: Float do
  alias AshLocalize.Context

  def format(n, opts) do
    Localize.Number.to_string!(n, locale: Context.locale!(%{}, argument: opts[:locale]))
  end
end

defimpl AshLocalize.Format, for: Decimal do
  alias AshLocalize.Context

  def format(n, opts) do
    Localize.Number.to_string!(n, locale: Context.locale!(%{}, argument: opts[:locale]))
  end
end

defimpl AshLocalize.Format, for: Date do
  alias AshLocalize.Context

  def format(date, opts) do
    Localize.Date.to_string!(date, locale: Context.locale!(%{}, argument: opts[:locale]))
  end
end

defimpl AshLocalize.Format, for: NaiveDateTime do
  alias AshLocalize.Context

  def format(datetime, opts) do
    Localize.DateTime.to_string!(datetime, locale: Context.locale!(%{}, argument: opts[:locale]))
  end
end

defimpl AshLocalize.Format, for: DateTime do
  alias AshLocalize.Context

  def format(datetime, opts) do
    Localize.DateTime.to_string!(datetime, locale: Context.locale!(%{}, argument: opts[:locale]))
  end
end

defimpl AshLocalize.Format, for: List do
  alias AshLocalize.Context

  def format(list, opts) do
    Localize.List.to_string!(list, locale: Context.locale!(%{}, argument: opts[:locale]))
  end
end

defimpl AshLocalize.Format, for: Localize.Unit do
  alias AshLocalize.Context

  def format(unit, opts) do
    Localize.Unit.to_string!(unit, locale: Context.locale!(%{}, argument: opts[:locale]))
  end
end

# Optional satellite types — each implementation is conditional on the satellite
# package being present at compile time. A consumer without the satellite gets no
# protocol implementation for its value type, which is fine because the value
# type itself can't exist without the satellite either.

if Code.ensure_loaded?(Money) do
  defimpl AshLocalize.Format, for: Money do
    alias AshLocalize.Context

    # %Money{} carries both amount and currency — the canonical "value carries its
    # dimension" shape. We pull both from the value itself.
    def format(money, opts) do
      Localize.Number.to_string!(Money.to_decimal(money),
        locale: Context.locale!(%{}, argument: opts[:locale]),
        currency: Money.to_currency_code(money)
      )
    end
  end
end

if Code.ensure_loaded?(Localize.Address.Address) do
  defimpl AshLocalize.Format, for: Localize.Address.Address do
    alias AshLocalize.Context

    def format(address, opts) do
      case Localize.Address.to_string(address,
             locale: Context.locale!(%{}, argument: opts[:locale])
           ) do
        {:ok, formatted} -> formatted
        {:error, reason} -> raise "AshLocalize could not format an address: #{inspect(reason)}"
      end
    end
  end
end

if Code.ensure_loaded?(Localize.PhoneNumber.Number) do
  defimpl AshLocalize.Format, for: Localize.PhoneNumber.Number do
    # Phone-number formatting is dialing-rules-driven, not locale-driven; the
    # `:format` style (`:international`, `:national`, `:e164`, `:rfc3966`) is the
    # axis that varies. Default to `:international`.
    def format(number, opts) do
      style = Keyword.get(opts, :format, :international)

      case Localize.PhoneNumber.to_string(number, style) do
        {:ok, formatted} -> formatted
        {:error, reason} -> raise "AshLocalize could not format a phone number: #{reason}"
      end
    end
  end
end

if Code.ensure_loaded?(Localize.PersonName) do
  defimpl AshLocalize.Format, for: Localize.PersonName do
    alias AshLocalize.Context

    @format_keys [:format, :usage, :formality, :order]

    def format(name, opts) do
      Localize.PersonName.to_string!(
        name,
        [{:locale, Context.locale!(%{}, argument: opts[:locale])} | Keyword.take(opts, @format_keys)]
      )
    end
  end
end
