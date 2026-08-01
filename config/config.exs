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
  subdivision: AshLocalize.Types.Subdivision,
  timezone: AshLocalize.Types.Timezone,
  currency_code: AshLocalize.Types.CurrencyCode,
  person_name: AshLocalize.Types.PersonName,
  count: AshLocalize.Types.Count,
  ordinal: AshLocalize.Types.Ordinal,
  percentage: AshLocalize.Types.Percentage,
  ratio: AshLocalize.Types.Ratio,
  score: AshLocalize.Types.Score,
  rating: AshLocalize.Types.Rating,
  unit: AshLocalize.Types.Unit,
  length: AshLocalize.Types.Length,
  distance: AshLocalize.Types.Distance,
  mass: AshLocalize.Types.Mass,
  speed: AshLocalize.Types.Speed,
  acceleration: AshLocalize.Types.Acceleration,
  force: AshLocalize.Types.Force,
  volume: AshLocalize.Types.Volume,
  area: AshLocalize.Types.Area,
  temperature: AshLocalize.Types.Temperature,
  energy: AshLocalize.Types.Energy,
  power: AshLocalize.Types.Power,
  pressure: AshLocalize.Types.Pressure,
  angle: AshLocalize.Types.Angle,
  frequency: AshLocalize.Types.Frequency,
  digital: AshLocalize.Types.Digital,
  electric_current: AshLocalize.Types.ElectricCurrent,
  voltage: AshLocalize.Types.Voltage

# ex_money 6.2 deprecates auto-starting the exchange rate service. We only ever
# format `%Money{}` values through `Localize.Chars` — no conversion, no rates —
# so opt out rather than start a retriever we never ask anything of.
config :ex_money, auto_start_exchange_rate_service: false

# Localize ships `:en` only; every other locale is fetched from the CDN and
# cached on disk. A miss falls back to `:und` *silently* — still `{:ok, ...}`,
# just formatted wrong — so a test suite without this configuration asserts
# English output under a German locale name and passes.
#
# `:otp_app` anchors the cache at `Application.app_dir(:ash_localize, ...)`,
# which re-resolves per environment, so `mix test` and mix tasks agree. Populate
# it with `mix localize.download_locales` — wired into the `test` alias.
config :localize,
  otp_app: :ash_localize,
  supported_locales: [:en, :de, :fr, :es, :ja, :ru, :ar, :"zh-Hant"]

# libphonenumber / libpostal are opt-in — see native_deps/0 in mix.exs. Registering
# a short name whose module does not exist makes every resource using it fail to
# compile, so these two are registered only when the packages are present.
if System.get_env("ASH_LOCALIZE_NATIVE") in ~w(1 true) do
  config :ash, :custom_types,
    phone_number: AshLocalize.Types.PhoneNumber,
    postal_address: AshLocalize.Types.PostalAddress
end
