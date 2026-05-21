import Config

# Application default locale. Required: AshLocalize.Context resolution falls back
# to this when no more specific locale is available.
config :ash_localize, default_locale: "en"

# Register short type names so resources can refer to the custom types by atom,
# e.g. `attribute :language, :locale`. Consuming applications must add the same
# block to their own config.
config :ash, :custom_types,
  locale: AshLocalize.Types.Locale,
  territory: AshLocalize.Types.Territory,
  currency_code: AshLocalize.Types.CurrencyCode
