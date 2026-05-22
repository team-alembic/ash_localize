# AshLocalize

Ash Framework integration for [Localize](https://github.com/elixir-localize/localize),
the CLDR-backed localization library for Elixir.

`ash_localize` gives Ash resources the locale-aware, CLDR-validated types every
application needs and most hand-roll badly — locales, territories, currency codes, and
units of measure — together with locale-aware formatting, translatable fields, and a
single deterministic locale-resolution chain.

> **Status: early development.** Phases 1–2 and the units-of-measure types are
> implemented — the `Locale`/`Territory`/`CurrencyCode` types and validations,
> `AshLocalize.Context` locale resolution, the locale-aware formatting calculations,
> per-category unit types (`Speed`, `Mass`, `Length`, …), and the `PersonName`,
> `PhoneNumber`, and `PostalAddress` types. See [`PLAN.md`](PLAN.md) for the roadmap.

## Types you should never reinvent

Every codebase grows its own half-broken versions of these — a `country` string nobody
validates, a `currency` column that accepts `"dollars"`, a distance stored as a bare
float with the unit hidden in a comment. `ash_localize` replaces them with real Ash
types: CLDR-validated, canonicalised, and working on every data layer.

### Units of measure

Physical quantities are first-class. Each category is its own type — the unit is
schema metadata, the column stores a plain number, and the loaded value is a
`%Localize.Unit{}` that knows its unit. The same handful of types span a recipe app
and a launch vehicle:

```elixir
# Everyday quantities
attribute :trail_length,    :length       # base: meter
attribute :ingredient_mass, :mass         # base: kilogram
attribute :oven_temp,       :temperature  # base: kelvin
attribute :floor_area,      :area         # base: square-meter
attribute :tank_volume,     :volume       # base: cubic-meter

# Engineering quantities
attribute :delta_v,         :speed        # spacecraft Δv, base: meter-per-second
attribute :engine_thrust,   :force        # thrust, base: newton
attribute :array_power,     :power        # base: watt
attribute :bus_voltage,     :voltage      # base: volt
attribute :gimbal_angle,    :angle        # base: radian

# Override the base unit per attribute
attribute :cruise_speed, :speed, constraints: [base_unit: "knot"]
```

Writes accept any dimensionally-compatible unit and convert — `delta_v: {7.8,
"kilometer-per-second"}` stores `7800` (m/s). A value from the wrong category — a mass
into a `:speed` — is rejected. Because the column is a plain number, `sum`, `avg`,
sorting, and filtering run natively in the data layer.

Categories: `length` (alias `distance`), `mass`, `speed`, `acceleration`, `force`,
`volume`, `area`, `temperature`, `energy`, `power`, `pressure`, `angle`, `frequency`,
`digital`, `electric_current`, `voltage`. The generic `:unit` type, given an explicit
`base_unit`, covers anything else.

### Locales, territories, and currency codes

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource, domain: MyApp.Accounts

  attributes do
    uuid_primary_key :id
    attribute :preferred_locale, :locale          # e.g. "en", "ja-JP"
    attribute :country, :territory                # e.g. "AU", "JP"
    attribute :billing_currency, :currency_code   # e.g. "AUD", "JPY"
  end
end
```

Each is a plain `Ash.Type` storing a string, with casting and validation routed through
Localize. Casting normalises input to CLDR's canonical form (`"en-us"` → `"en-US"`) and
rejects values CLDR does not recognise — both malformed strings and well-formed but
unknown subtags.

### Person names

```elixir
attribute :author_name, :person_name
```

Stored as name parts (`given_name`, `surname`, `title`, …), rendered with culturally
correct order, formality, and addressing by `FormatPersonName` — `"Ada Lovelace"` or
`"Dr. Lovelace"` depending on locale and usage. Needs the optional `localize_person_names`
dependency.

### Phone numbers and postal addresses

```elixir
attribute :contact_phone, :phone_number
attribute :shipping_address, :postal_address
```

`:phone_number` parses and validates via libphonenumber, stores E.164, and formats as
`:international` / `:national` / `:e164`. `:postal_address` holds CLDR address
components and renders country-correct, multi-line labels. Both need optional
dependencies — see [Optional integrations](#optional-integrations).

## Installation

```elixir
def deps do
  [
    {:ash_localize, "~> 0.1"}
  ]
end
```

Configure an application default locale. It is the final arm of locale resolution;
without it, resolution reports `{:error, :no_locale}` rather than a silent `nil`:

```elixir
config :ash_localize, default_locale: "en"
```

Register the short type names you use so resources can refer to them by atom:

```elixir
config :ash, :custom_types,
  locale: AshLocalize.Types.Locale,
  territory: AshLocalize.Types.Territory,
  currency_code: AshLocalize.Types.CurrencyCode,
  # unit-of-measure types — register the categories you use
  speed: AshLocalize.Types.Speed,
  mass: AshLocalize.Types.Mass,
  length: AshLocalize.Types.Length
```

## Validations

When you would rather keep a plain `:string` attribute but still guard its contents,
use the validations directly:

```elixir
validations do
  validate {AshLocalize.Validations.ValidLocale, attribute: :preferred_locale}
  validate {AshLocalize.Validations.ValidTerritory, attribute: :country}
  validate {AshLocalize.Validations.ValidCurrencyCode, attribute: :billing_currency}
end
```

## Locale resolution

`AshLocalize.Context.locale/2` resolves the active locale from one deterministic chain,
most specific first:

1. **Explicit argument** — a `:locale` action/calculation argument.
2. **Ash context** — the `:locale` key in `Ash.Context`.
3. **Actor-derived** — opt-in via the `:actor_locale` option.
4. **Application default** — `config :ash_localize, default_locale: ...`.

The process dictionary and tenant are deliberately excluded; see `PLAN.md` for the
rationale.

```elixir
{:ok, "ja-JP"} = AshLocalize.Context.locale(%{locale: "ja-JP"}, [])
"en" = AshLocalize.Context.locale!(%{}, [])
```

## Formatting calculations

Locale-aware formatting is exposed as Ash calculations. Each renders a source
attribute through Localize, resolving the locale from the chain above.

```elixir
calculations do
  calculate :formatted_quantity, :string,
    {AshLocalize.Calculations.FormatNumber, field: :quantity}

  calculate :formatted_price, :string,
    {AshLocalize.Calculations.FormatCurrency, field: :price, currency: "USD"}

  calculate :starts_on, :string,
    {AshLocalize.Calculations.FormatDate, field: :start_date}

  calculate :starts_at, :string,
    {AshLocalize.Calculations.FormatDateTime, field: :start_at}

  calculate :formatted_tags, :string,
    {AshLocalize.Calculations.FormatList, field: :tags}

  calculate :formatted_delta_v, :string,
    {AshLocalize.Calculations.FormatUnit, field: :delta_v}
end
```

`FormatCurrency` also accepts `currency_field:` to read the currency code per record
from a sibling attribute. A `nil` source value yields `nil`. Add a `:locale` argument
to a calculation to feed the explicit-argument arm of locale resolution.

## Optional integrations

`ash_localize` is a single package. Its heavier capabilities are optional dependencies,
compiled in only when your application also declares the upstream package:

| Add to your deps                      | Unlocks                                              |
| -------------------------------------- | ---------------------------------------------------- |
| `localize_phone_number` (git)          | the `:phone_number` type (libphonenumber)            |
| `localize_address`                     | the `:postal_address` type (libpostal)               |
| `localize_person_names`                | the `:person_name` type                              |
| `localize_translate`                   | the `LocalizeTranslate` translation store            |
| `ash_postgres` + `localize_units_sql`  | native composite types, ICU collation, migrations    |
| `ash_phoenix` + `localize_web`         | the locale plug and `<.ash_input>` form helpers      |

Without them, the core — locale/territory/currency/unit types, formatting, and
validations — works on every Ash data layer with no extra weight.

## License

Apache 2.0 — see [`LICENSE`](LICENSE).
