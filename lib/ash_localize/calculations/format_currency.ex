defmodule AshLocalize.Calculations.FormatCurrency do
  @moduledoc """
  An Ash calculation that renders a numeric amount as a locale-formatted currency string.

  The locale is resolved through `AshLocalize.Context`. The currency is either fixed for
  the calculation or read per record from a sibling attribute.

      calculations do
        # fixed currency
        calculate :formatted_price, :string,
          {AshLocalize.Calculations.FormatCurrency, field: :price, currency: "USD"}

        # per-record currency
        calculate :formatted_total, :string,
          {AshLocalize.Calculations.FormatCurrency,
           field: :total, currency_field: :currency_code}
      end

  ## Options

    * `:field` (required) — the atom name of the numeric amount attribute.
    * `:currency` — a fixed ISO 4217 currency code (string or atom).
    * `:currency_field` — the atom name of a sibling attribute holding the currency code.

  Exactly one of `:currency` or `:currency_field` is required. A `nil` amount — or a
  `nil` per-record currency — produces a `nil` result.
  """

  use Ash.Resource.Calculation

  alias AshLocalize.Calculations.Helpers

  @impl true
  def init(opts) do
    with {:ok, opts} <- Helpers.require_field(opts) do
      cond do
        opts[:currency] ->
          {:ok, opts}

        is_atom(opts[:currency_field]) and not is_nil(opts[:currency_field]) ->
          {:ok, opts}

        true ->
          {:error, "a `:currency` or `:currency_field` option is required"}
      end
    end
  end

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
      case currency(opts, record) do
        nil -> nil
        currency -> Localize.Number.to_string!(amount, locale: locale, currency: currency)
      end
    end)
  end

  defp currency(opts, record) do
    case opts[:currency] do
      nil -> Map.get(record, opts[:currency_field])
      currency -> currency
    end
  end
end
