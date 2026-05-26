# AshLocalize

Ash Framework integration for [Localize](https://github.com/elixir-localize/localize),
the CLDR-backed localization library for Elixir.

`ash_localize` gives Ash resources the locale-aware, CLDR-validated types every business
application needs. locales, territories, currency codes, and units of measure, together with locale-aware formatting, translatable fields, and a single deterministic locale-resolution chain.

> **Status: early development.** Phases 1–2 and the units-of-measure types are
> implemented — the `Locale`/`Territory`/`Subdivision`/`Timezone`/`CurrencyCode`
> types and validations, `AshLocalize.Context` locale resolution, the locale-aware
> formatting calculations, per-category unit types (`Speed`, `Mass`, `Length`, …),
> the `PersonName`, `PhoneNumber`, and `PostalAddress` types, and the numeric
> semantic types (`Count`, `Ordinal`, `Percentage`, `Ratio`, `Score`, `Rating`).
> See [`PLAN.md`](PLAN.md) for the roadmap.

## Types you should never reinvent

Every codebase grows its own half-broken versions of these — a `country` string nobody
validates, a `currency` column that accepts `"dollars"`, a distance stored as a bare
float with the unit hidden in a comment. `ash_localize` replaces them with real Ash
types: CLDR-validated, canonicalised, and working on every data layer.

### Units of Measure

Physical quantities are first-class. Each category is its own type: the unit is
schema metadata, the column stores a plain number, and the loaded value is a
`%Localize.Unit{}` that knows its unit. The same handful of types span recipe,
rockets and industrial robots, and everything in between:

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
`base_unit`, covers anything else — and `AshLocalize.UnitType` lets you define your
own reusable types (*jerk*, specific impulse, anything you want). See the
[Custom units guide](documentation/custom_units.md).

### Locales, territories, subdivisions, timezones, and currency codes

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource, domain: MyApp.Accounts

  attributes do
    uuid_primary_key :id
    attribute :preferred_locale, :locale          # e.g. "en", "ja-JP"
    attribute :country,          :territory       # e.g. "AU", "JP"
    attribute :state,            :subdivision,    # e.g. "caon", "usca"
              constraints: [territory: :US]
    attribute :timezone,         :timezone        # e.g. "Australia/Sydney"
    attribute :billing_currency, :currency_code   # e.g. "AUD", "JPY"
  end
end
```

Each is a plain `Ash.Type` storing a string, with casting and validation routed through
Localize. Casting normalises input to CLDR's canonical form (`"en-us"` → `"en-US"`,
`"Australia/ACT"` → `"Australia/Sydney"`) and rejects values CLDR does not recognise —
both malformed strings and well-formed but unknown subtags. The `:subdivision`
type's optional `:territory` constraint additionally rejects subdivisions outside
the named country.

### Person names

```elixir
attribute :author_name, :person_name
```

Stored as name parts (`given_name`, `surname`, `title`, …), rendered with culturally
correct order, formality, and addressing by `FormatPersonName` — `"Ada Lovelace"` or
`"Dr. Lovelace"` depending on locale and usage. Needs the optional `localize_person_names`
dependency.

### Numeric semantic types

Numbers carry meaning. These types capture *what* a number is — a count of something,
a rank, a percentage — and render it locale-correctly:

```elixir
attribute :comment_count, :count, constraints: [of: :comments]
attribute :rank,          :ordinal
attribute :completion,    :percentage              # 0.75 → "75%"
attribute :compression,   :ratio                   # 0.75 → "3⁄4"
attribute :priority,      :score, constraints: [min: 0, max: 100]
attribute :customer_rating, :rating, constraints: [out_of: 5, of: :stars]
```

Each pairs with a `Format*` calculation. `FormatCount` is plural-aware via MF2 — the
same template can render `"No comments"` / `"1 comment"` / `"27 comments"` in English
and `"3件のコメント"` in Japanese; the `:of` tag is the key the future translation
catalogue will use to pick locale-specific templates and counter words.

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

With [Igniter](https://hexdocs.pm/igniter) — adds the dep and writes the config
for you, detecting any optional satellite packages already in your deps:

```bash
mix igniter.install ash_localize
```

Or manually — add the dep:

```elixir
def deps do
  [
    {:ash_localize, "~> 0.1"}
  ]
end
```

Then configure an application default locale. It is the final arm of locale
resolution; without it, resolution reports `{:error, :no_locale}` rather than a
silent `nil`:

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

Locale-aware formatting is exposed as Ash calculations. Each pairs a source
attribute with a calc that renders it through Localize, resolving the locale from
the chain above. Money is shown first because it's the defining example of this
library's whole stance: **the value carries its dimension** — currency for money,
base unit for `:speed`, IANA name for `:timezone`, full BCP 47 tag for `:locale`.
Bare numbers with their unit hidden in a sibling column are exactly the shape
this library is built to retire.

```elixir
attributes do
  # %Money{} from ex_money / AshMoney — amount and currency are one value.
  # No companion `:currency_code` column; aggregation, arithmetic, and rendering
  # all treat the pair atomically.
  attribute :price, AshMoney.Types.Money, public?: true

  # A dimensioned quantity. The base unit is type metadata (here: m/s); writes
  # accept any compatible unit and convert. The loaded value is a
  # %Localize.Unit{} that knows its unit.
  attribute :delta_v, :speed, public?: true

  # An integer that needs locale-correct thousands separators
  # ("1,234" en / "1.234" de / "1 234" fr).
  attribute :word_count, :integer, public?: true

  # Date and UTC datetime rendered with locale-correct field ordering, month
  # names, and time format ("Apr 5, 2026" vs "5. Apr. 2026").
  attribute :starts_on, :date,         public?: true
  attribute :ends_at,   :utc_datetime, public?: true

  # A list whose joiner depends on locale ("a, b, and c" vs "a、b、c").
  attribute :tags, {:array, :string}, public?: true
end

calculations do
  # Currency comes from the %Money{} value itself — no :currency option needed.
  # An order in JPY renders "¥1,500"; one in EUR renders "1.500,00 €".
  calculate :price_label, :string,
    {AshLocalize.Calculations.FormatCurrency, field: :price}

  calculate :delta_v_label, :string,
    {AshLocalize.Calculations.FormatUnit, field: :delta_v}

  calculate :word_count_label, :string,
    {AshLocalize.Calculations.FormatNumber, field: :word_count}

  calculate :starts_on_label, :string,
    {AshLocalize.Calculations.FormatDate, field: :starts_on}

  calculate :ends_at_label, :string,
    {AshLocalize.Calculations.FormatDateTime, field: :ends_at}

  calculate :tags_label, :string,
    {AshLocalize.Calculations.FormatList, field: :tags}
end
```

A `nil` source value yields a `nil` result. Add a `:locale` argument to a
calculation to feed the explicit-argument arm of locale resolution.

### Money sources

`FormatCurrency` natively accepts a `%Money{}` source (from
[ex_money](https://hexdocs.pm/ex_money), or the loaded value of
[`AshMoney.Types.Money`](https://hexdocs.pm/ash_money)) and pulls the currency
from the value itself. This is the recommended shape: amount and currency stay
coupled — splitting them into two attributes invites the same class of bug as
storing "distance: 100" with the unit hidden in a comment.

For legacy resources where money is already split across two columns,
`FormatCurrency` also takes a fixed `currency: "USD"` (one currency for the
whole resource) or `currency_field: :some_attr` (per-record code from a
sibling). Use these only as a migration ramp toward Money.

## Optional integrations

`ash_localize` is a single package. Its heavier capabilities are optional dependencies,
compiled in only when your application also declares the upstream package:

| Add to your deps                      | Unlocks                                           |
| ------------------------------------- | ------------------------------------------------- |
| `localize_phone_number` (git)         | the `:phone_number` type (libphonenumber)         |
| `localize_address`                    | the `:postal_address` type (libpostal)            |
| `localize_person_names`               | the `:person_name` type                           |
| `localize_translate`                  | the `LocalizeTranslate` translation store         |
| `ash_postgres` + `localize_units_sql` | native composite types, ICU collation, migrations |
| `ash_phoenix` + `localize_web`        | the locale plug and `<.ash_input>` form helpers   |

Without them, the core — locale/territory/currency/unit types, formatting, and
validations — works on every Ash data layer with no extra weight.

## License

Apache 2.0 — see [`LICENSE`](LICENSE).
