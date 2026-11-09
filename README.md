# AshLocalize

The Ash Framework layer over [Localize](https://github.com/elixir-localize/localize),
the CLDR-backed localization library for Elixir.

Localize knows how to validate a territory code and how to render a number in
German. It does not know anything about Ash. `ash_localize` is the join: Ash types
that validate through Localize, calculations that render through it, and one place
that decides which locale is active for a given operation.

> **Status: early development.** The types, formatting, error messages and locale
> resolution described below are implemented and tested. The AshPostgres,
> AshPhoenix, AshGraphql and AshJsonApi integrations, and the translated-content
> DSL, are not yet built — see [`docs/PLAN.md`](docs/PLAN.md).

## Validated codes

Most applications have a country column, a currency column, and a timezone column.
Usually they are `:string`, and usually nothing checks them, so `"Straya"`,
`"dollars"` and `"AEST"` all get in and fail somewhere further away.

```elixir
attributes do
  attribute :preferred_locale, :locale        # "en", "ja-JP"
  attribute :country,          :territory     # "AU", "JP"
  attribute :state,            :subdivision, constraints: [territory: :US]
  attribute :timezone,         :timezone      # "Australia/Sydney"
  attribute :billing_currency, :currency_code # "AUD", "JPY"
end
```

Each stores a string, so every data layer works unchanged. Casting goes through
Localize: unknown values are rejected — both malformed strings and well-formed but
non-existent subtags — and accepted values are stored canonically. `"en-us"` becomes
`"en-US"`, `"aud"` becomes `"AUD"`, and the IANA alias `"Australia/ACT"` becomes
`"Australia/Sydney"`, so equality comparisons stop depending on how the value was
typed.

If you would rather keep a plain `:string` and only guard its contents:

```elixir
validations do
  validate {AshLocalize.Validations.ValidLocale, attribute: :preferred_locale}
  validate {AshLocalize.Validations.ValidTerritory, attribute: :country}
  validate {AshLocalize.Validations.ValidCurrencyCode, attribute: :billing_currency}
end
```

## Formatting

`to_string/1` on a `Decimal` gives `1234.5` to every user on earth. Rendering it as
`1.234,5` for a German one means knowing the locale and calling the right Localize
function for the value's type, at every call site.

`AshLocalize.format/1` dispatches on the value:

```elixir
AshLocalize.format(order.total)        # "$1,234.50"
AshLocalize.format(order.starts_on)    # "May 22, 2026"
AshLocalize.format(order.tags)         # "apples, oranges, and pears"
AshLocalize.format(order.delta_v)      # "7,800 m/s"

AshLocalize.format(order.total, locale: "de")      # "1.234,50 $"
AshLocalize.format(order.starts_on, locale: "ja")  # "2026/05/22"
```

This is the upstream `Localize.Chars` protocol, which already covers integers,
floats, decimals, dates, times, datetimes, ranges, lists, durations and language
tags. `ash_localize` adds one implementation of its own, for `%Money{}`. Anything
Localize or its satellite packages can render, `format/1` renders.

For API consumers that need a *field* rather than an Elixir call — AshGraphql,
AshJsonApi, AshAdmin — there are fifteen `Format*` calculations:

```elixir
calculations do
  calculate :total_label, :string,
    {AshLocalize.Calculations.FormatCurrency, field: :total}

  calculate :starts_on_label, :string,
    {AshLocalize.Calculations.FormatDate, field: :starts_on}
end
```

They read the locale from calculation context rather than the process dictionary,
so they stay correct under Ash's parallel loads. A `nil` source always yields `nil`.

## Error messages

Ash marks its error messages for extraction and ships them in a `.pot` file. The
extraction half works. The rendering half has three problems, and all three are in
the *values* rather than the words, so no `.po` file can fix them:

- Interpolated numbers are unformatted, so a German user reads `1234.5`.
- Lists arrive joined with an English comma, decided before any translator sees it.
- There is no plural selection in any locale. Gettext selects on a variable named
  `count`, and **none** of Ash's 58 shipped messages use that name — the counted
  ones are named after the constraint (`%{at_least}`, `%{precision}`). Every Ash
  error renders singular-only, so Russian gets one form where it needs three.

```elixir
AshLocalize.translate_error({"must be less than or equal to %{max}", max: 1234}, locale: "de")
#=> "must be less than or equal to 1.234"
```

That works with nothing translated. Where a MessageFormat 2 translation exists, the
plural is selected properly regardless of what the variable is called:

```
ru, selecting on `at_least`:
  1  → нужно указать минимум 1 поле     (one)
  5  → нужно указать минимум 5 полей    (many)
  21 → нужно указать минимум 21 поле    (one)
```

Translations live in a catalogue you can replace — see
`AshLocalize.ErrorMessage.Catalogue`. The shipped one is a seed.

## Numbers that mean something

`:integer` stores a number and discards what it was counting, which is why
pluralising it later needs the noun passed in by hand at every call site.

```elixir
attribute :comment_count, :count, constraints: [of: :comments]
attribute :rank,          :ordinal
attribute :completion,    :percentage                            # 0.75 → "75%"
attribute :compression,   :ratio                                 # 0.75 → "3⁄4"
attribute :priority,      :score,  constraints: [min: 0, max: 100]
attribute :stars,         :rating, constraints: [out_of: 5, of: :stars]
```

Storage stays a plain number, so `sum`, `avg`, sorting and filtering run natively.
The constraint is metadata that makes correct rendering possible: `FormatCount` uses
`:of` to select a plural form, and `:ordinal` renders `"1st"`, `"1er"` or `"第1"`
rather than `1`.

## Money

Two columns — an amount and a currency code — drift. One gets written and the other
does not, or a `sum` runs across mixed currencies.

```elixir
attribute :price, AshMoney.Types.Money
```

`ash_money` owns that type; `ash_localize` adds the rendering, pulling the currency
from the value itself. `FormatCurrency` also accepts a fixed `currency: "USD"` or a
`currency_field: :some_attr` for schemas already split across two columns — use them
as a migration ramp, not a destination.

## Units of measure

A distance stored as a bare float has its unit in a comment, or in a column name, or
in nobody's head. Conversions then happen wherever someone remembers to do them.

```elixir
attribute :trail_length, :length       # base: meter
attribute :oven_temp,    :temperature  # base: kelvin
attribute :delta_v,      :speed        # base: meter-per-second

attribute :cruise_speed, :speed, constraints: [base_unit: "knot"]
```

The unit is type metadata. The column holds a plain number in the base unit, so
aggregates and sorting stay native on every data layer, and the loaded value is a
`%Localize.Unit{}` that knows what it is. Writes take any dimensionally compatible
unit and convert — `delta_v: {7.8, "kilometer-per-second"}` stores `7800` — and a
mass written into a `:speed` is rejected.

Sixteen categories ship: `length` (with `distance` as an alias), `mass`, `speed`,
`acceleration`, `force`, `volume`, `area`, `temperature`, `energy`, `power`,
`pressure`, `angle`, `frequency`, `digital`, `electric_current`, `voltage`. The
generic `:unit` covers anything else given a `base_unit`, and you can define your own
— see [Custom units](documentation/custom_units.md).

## Names, phone numbers, addresses

"First name" and "last name" describe a minority of the world's names, and a single
`address` textarea cannot be rendered correctly for two different countries.

```elixir
attribute :author_name,      :person_name
attribute :contact_phone,    :phone_number
attribute :shipping_address, :postal_address
```

Names store their parts and render in culturally correct order and formality. Phone
numbers are parsed and validated with libphonenumber and stored as E.164, then
rendered `:international`, `:national` or `:e164`. Addresses store CLDR components
and render country-correct multi-line labels.

Each needs its optional dependency — see [Optional integrations](#optional-integrations).

## Which locale is active

Everything above needs to know the locale. Localize keeps it in the process
dictionary, which does not survive the processes Ash spawns for parallel loads and
async calculations — so a value formatted inside one silently comes back in the
default locale.

`AshLocalize.Context.locale/2` resolves it from one chain, most specific first:

1. **Explicit argument** — a `:locale` action or calculation argument.
2. **Ash context** — the `:locale` key, which Ash propagates.
3. **Actor-derived** — opt-in, via the `:actor_locale` option.
4. **Application default** — `config :ash_localize, default_locale: ...`.

```elixir
{:ok, "ja-JP"} = AshLocalize.Context.locale(%{locale: "ja-JP"}, [])
```

The process dictionary is deliberately not an arm of that chain, and neither is
tenant. Unset with no default configured returns `{:error, :no_locale}` rather than
a silent `nil`.

## Phoenix inputs

With `phoenix_live_view` in your deps, `AshLocalize.Phoenix.Components` provides
form inputs for the `:locale`, `:timezone` and `:person_name` types. Each takes a
form field and builds its labels from CLDR:

```heex
<.locale_select field={@form[:locale]} prompt={gettext("Use the default")} />

<.timezone_input field={@form[:timezone]} placeholder={gettext("Search time zones")} />

<.person_name_input
  field={@form[:name]}
  labels={%{given_name: gettext("Given name"), surname: gettext("Surname")}}
/>
```

`locale_select` labels each locale in its own language, "🇩🇪 Deutsch
(Deutschland)". `timezone_input` lists every canonical IANA zone in a `<datalist>`,
labelled in the current locale: "London · British Time (GMT+00:00)". The offset
needs a time zone database such as `tz` or `tzdata`. `person_name_input` orders
its inputs the way the locale orders names, so `ja` puts the surname first. An
untouched input submits `""`, and the types cast that to `nil`.

Import the components with `import AshLocalize.Phoenix.Components`.
`AshLocalize.Phoenix.text_direction/1` returns `"rtl"` or `"ltr"` for a locale,
for the `dir` attribute of your root layout.

## Adding your own types

Three kinds, three macros. The distinction is what the value *is*:

| Kind | The value is | Macro |
| --- | --- | --- |
| Code | a member of a controlled vocabulary | `AshLocalize.CodeType` |
| Quantity | a dimensionless magnitude | `AshLocalize.QuantityType` |
| Unit | a dimensioned magnitude | `AshLocalize.UnitType` |

A code cannot be ordered or aggregated — comparing two is equality, not magnitude.
A quantity can be; whether it carries a dimension decides the other two.

```bash
mix ash_localize.gen.type MyApp.Types.Script --kind code \
  --validator Localize.validate_script --short-name script
```

See [Adding a type](documentation/custom_types.md).

## Installation

```bash
mix igniter.install ash_localize
```

That adds the dependency, sets a default locale, registers a starting set of short
type names, and detects which optional packages you already have. Or add it by hand:

```elixir
{:ash_localize, "~> 0.1"}
```

```elixir
config :ash_localize, default_locale: "en"

config :ash, :custom_types,
  locale: AshLocalize.Types.Locale,
  territory: AshLocalize.Types.Territory,
  currency_code: AshLocalize.Types.CurrencyCode
```

Short names are optional — a type is always usable by module — but they are what
lets a resource write `attribute :country, :territory`.

### Locale data

Localize ships `:en` and fetches every other locale from its CDN. **A locale it
cannot find falls back to `:und` and still returns `{:ok, ...}`** — the output is
wrong for the requested locale and nothing in the return value says so. Configure
what you support and download it at build time:

```elixir
config :localize,
  otp_app: :my_app,
  supported_locales: [:en, :de, :fr, :ja]
```

```bash
mix localize.download_locales
```

Run that in your Dockerfile or CI build step. It only reaches the network for a
locale that is missing or version-stale on disk, and it halts on failure — so a
CDN outage fails your build rather than quietly shipping `:und` output. Cache the
cache directory if your CI makes that easy.

## Optional integrations

One package. The heavier capabilities compile in only when your application also
declares the upstream package, so declaring nothing costs nothing:

| Add to your deps | Unlocks |
| --- | --- |
| `ash_money` | `%Money{}` formatting, and its `:money` type |
| `localize_person_names` | `:person_name` |
| `localize_phone_number` | `:phone_number` (libphonenumber) |
| `localize_address` | `:postal_address` (libpostal) |
| `phoenix_live_view` | [Phoenix inputs](#phoenix-inputs) |

Planned, and not yet built: `ash_postgres` + `localize_sql` for native composite
types, ICU collation and migrations; `ash_phoenix` + `localize_web` for the locale
plug and the `<.ash_input>` dispatcher; `localize_translate` for translated content.

## License

Apache 2.0 — see [`LICENSE`](LICENSE).
