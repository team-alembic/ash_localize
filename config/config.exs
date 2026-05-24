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
  phone_number: AshLocalize.Types.PhoneNumber,
  postal_address: AshLocalize.Types.PostalAddress,
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
