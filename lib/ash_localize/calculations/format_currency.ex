defmodule AshLocalize.Calculations.FormatCurrency do
  @moduledoc """
  An Ash calculation that renders a monetary amount as a locale-formatted currency string.

  The locale is resolved through `AshLocalize.Context`. There are three supported
  shapes for the source value, in order of preference:

    * a `%Money{}` from [`ex_money`](https://hexdocs.pm/ex_money) (also the loaded
      value of `AshMoney.Types.Money`). Currency is taken from the value itself —
      keeping amount and currency coupled, as money should be modelled. Any
      `:currency` / `:currency_field` option is ignored;

    * a bare number / `Decimal`, paired with a fixed `:currency` (e.g.
      `currency: "USD"`) when every row is denominated the same way;

    * a bare number / `Decimal`, paired with `:currency_field` pointing at a
      sibling `:currency_code` attribute, when the currency varies per row.

  ```elixir
  calculations do
    # %Money{} source — currency is intrinsic
    calculate :formatted_price, :string,
      {AshLocalize.Calculations.FormatCurrency, field: :price}

    # bare amount + fixed currency
    calculate :formatted_subtotal, :string,
      {AshLocalize.Calculations.FormatCurrency, field: :subtotal, currency: "USD"}

    # bare amount + per-record currency
    calculate :formatted_total, :string,
      {AshLocalize.Calculations.FormatCurrency,
       field: :total, currency_field: :currency_code}
  end
  ```

  ## Options

    * `:field` (required) — the atom name of the source attribute.
    * `:currency` — a fixed ISO 4217 currency code (string or atom). Used only
      when the value is not a `%Money{}`.
    * `:currency_field` — the atom name of a sibling attribute holding the
      currency code. Used only when the value is not a `%Money{}`.

  At least one of those three must produce a currency at calculate time. A `nil`
  amount — or a `nil` per-record currency for a bare-number source — produces a
  `nil` result.
  """

  use Ash.Resource.Calculation

  alias AshLocalize.Calculations.Helpers

  @impl true
  def init(opts), do: Helpers.require_field(opts)

  @impl true
  def load(_query, opts, _context) do
    case opts[:currency_field] do
      nil -> [opts[:field]]
      currency_field -> [opts[:field], currency_field]
    end
  end

  @impl true
  def calculate(records, opts, context) do
    Helpers.format(records, opts, context, fn amount, locale, record ->
      case unpack(amount, opts, record) do
        {amount, currency} ->
          Localize.Number.to_string!(amount, locale: locale, currency: currency)

        nil ->
          nil
      end
    end)
  end

  # Money values carry their own currency; any opts-supplied currency is ignored.
  # This keeps amount and currency coupled — the whole point of using Money in the
  # first place — instead of letting a sibling attribute override the value.
  if Code.ensure_loaded?(Money) do
    defp unpack(%Money{} = money, _opts, _record) do
      {Money.to_decimal(money), Money.to_currency_code(money)}
    end
  end

  defp unpack(amount, opts, record) do
    case currency(opts, record) do
      nil -> nil
      currency -> {amount, currency}
    end
  end

  defp currency(opts, record) do
    case opts[:currency] do
      nil ->
        case opts[:currency_field] do
          nil -> nil
          field -> Map.get(record, field)
        end

      currency ->
        currency
    end
  end
end
