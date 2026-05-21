defmodule AshLocalize.Test.Profile do
  @moduledoc false
  # Test-support resource exercising the Phase 1 types and validations.
  #
  # The typed attributes (`:locale`, `:territory`, `:currency_code`) verify the custom
  # Ash types; the `raw_*` plain-string attributes verify the validations.

  use Ash.Resource,
    domain: AshLocalize.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id

    attribute :locale, :locale, public?: true
    attribute :territory, :territory, public?: true
    attribute :currency_code, :currency_code, public?: true

    attribute :raw_locale, :string, public?: true
    attribute :raw_territory, :string, public?: true
    attribute :raw_currency, :string, public?: true

    # Source attributes for the formatting calculations.
    attribute :price, :decimal, public?: true
    attribute :currency, :string, public?: true
    attribute :event_date, :date, public?: true
    attribute :event_at, :utc_datetime, public?: true
    attribute :tags, {:array, :string}, public?: true
  end

  validations do
    validate {AshLocalize.Validations.ValidLocale, attribute: :raw_locale}
    validate {AshLocalize.Validations.ValidTerritory, attribute: :raw_territory}
    validate {AshLocalize.Validations.ValidCurrencyCode, attribute: :raw_currency}
  end

  actions do
    default_accept :*
    defaults [:create, :read]
  end

  calculations do
    calculate :formatted_price, :string, {AshLocalize.Calculations.FormatNumber, field: :price}

    calculate :formatted_price_usd,
              :string,
              {AshLocalize.Calculations.FormatCurrency, field: :price, currency: "USD"}

    calculate :formatted_price_dynamic,
              :string,
              {AshLocalize.Calculations.FormatCurrency, field: :price, currency_field: :currency}

    calculate :formatted_event_date,
              :string,
              {AshLocalize.Calculations.FormatDate, field: :event_date}

    calculate :formatted_event_at,
              :string,
              {AshLocalize.Calculations.FormatDateTime, field: :event_at}

    calculate :formatted_tags, :string, {AshLocalize.Calculations.FormatList, field: :tags}
  end
end
