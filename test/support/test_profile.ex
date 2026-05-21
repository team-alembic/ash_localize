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
end
