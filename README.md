# AshLocalize

Ash Framework integration for [Localize](https://github.com/elixir-localize/localize),
the CLDR-backed localization library for Elixir.

`ash_localize` makes Ash resources locale-aware at the resource level: CLDR-validated
typed attributes, locale-aware formatting as calculations, translatable string fields,
and a single deterministic locale-resolution chain.

> **Status: early development.** Phases 1–2 and the units-of-measure types are
> implemented — the `Locale`/`Territory`/`CurrencyCode` types and validations,
> `AshLocalize.Context` locale resolution, the locale-aware formatting calculations,
> and per-category unit types (`Speed`, `Mass`, `Length`, …). See [`PLAN.md`](PLAN.md)
> for the full roadmap.

## The ash_localize family

| Package                  | Purpose                                                                              |
| ------------------------ | ------------------------------------------------------------------------------------ |
| `ash_localize`           | Data-layer-agnostic core: types, validations, formatting calculations, translations. |
| `ash_localize_postgres`  | AshPostgres optimisations: native composite types, ICU collation, JSONB helpers.     |
| `ash_localize_phoenix`   | Phoenix/LiveView bridge: locale plug and form rendering.                             |

Only `ash_localize` exists today.

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

Register the short type names so resources can refer to the custom types by atom:

```elixir
config :ash, :custom_types,
  locale: AshLocalize.Types.Locale,
  territory: AshLocalize.Types.Territory,
  currency_code: AshLocalize.Types.CurrencyCode
```

## Types

Each type is a plain `Ash.Type` storing a string, with casting and validation routed
through Localize. They work on every Ash data layer.

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

Casting normalises input (Localize's canonical form) and rejects values CLDR does not
recognise.

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
end
```

`FormatCurrency` also accepts `currency_field:` to read the currency code per record
from a sibling attribute. A `nil` source value yields `nil`. Add a `:locale` argument
to a calculation to feed the explicit-argument arm of locale resolution.

## Units of measure

Physical quantities are first-class. Each category is its own type — the unit is
schema metadata, the column stores a plain number, and the loaded value is a
`%Localize.Unit{}` that knows its unit.

```elixir
attribute :delta_v,  :speed                                    # base: meter-per-second
attribute :altitude, :length                                   # base: meter
attribute :dry_mass, :mass                                      # base: kilogram
attribute :thrust,   :force                                     # base: newton
attribute :cruise,   :speed, constraints: [base_unit: "knot"]   # override the base
```

Writes accept any dimensionally-compatible unit and convert — `delta_v: {7.8,
"kilometer-per-second"}` stores `7800` (m/s). A value from the wrong category — a mass
into a `:speed` — is rejected. Because the column is a plain number, `sum`, `avg`,
sorting, and filtering run natively in the data layer.

Categories: `length` (alias `distance`), `mass`, `speed`, `acceleration`, `force`,
`volume`, `area`, `temperature`, `energy`, `power`, `pressure`, `angle`, `frequency`,
`digital`, `electric_current`, `voltage`. The generic `:unit` type, given an explicit
`base_unit`, covers anything else. Render with `AshLocalize.Calculations.FormatUnit`.

## License

Apache 2.0 — see [`LICENSE`](LICENSE).
