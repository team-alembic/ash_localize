# Changelog

All notable changes to this project are documented here.

## [Unreleased]

### Added

- `AshLocalize.translate_error/1,2` — renders Ash error messages with
  locale-correct interpolated values, and with MessageFormat 2 plural selection
  where a translation exists. Ash's extraction pipeline (`Ash.Gettext`,
  `mix ash.gettext.extract`, `priv/gettext/ash.pot`) is sound; the rendering half
  has three defects that live in the *values* rather than the words, so no `.po`
  file can repair them:

  1. Interpolated numbers are unformatted — Ash's `decimal.ex` and `float.ex`
     pass raw numbers into `"must be less than or equal to %{max}"`, so a German
     user reads `1234.5` where they expect `1.234,5`.
  2. Lists are joined with an English comma before a translator sees them —
     `Enum.join(attributes, ", ")` in `validation/present.ex`.
  3. There is no plural selection in any locale. Gettext selects on a variable
     named `count`, and there are zero occurrences of `%{count}` across Ash's 58
     shipped msgids; the counted ones name the variable after the constraint
     (`%{at_least}`, `%{precision}`). Every Ash error renders through
     singular-only `dgettext`, so Russian and Polish get one form where they need
     three.

  Accepts the `{message, vars}` shape Phoenix's `translate_error/1` convention
  uses, a bare string, or an Ash error struct. Requires no change to Ash.

- `AshLocalize.ErrorMessage.Catalogue` — behaviour for MF2 translations of Ash
  msgids, with `Catalogue.Builtin` reading `priv/messages/ash/<locale>.exs` at
  compile time and falling back along locale subtags (`de-AT` → `de`). Swap it
  with `config :ash_localize, error_catalogue: MyApp.Catalogue`. The shipped
  catalogue is a seed pending translator review — an untranslated msgid falls
  back to the English string with locale-correct values, which still fixes (1)
  and (2) above without a word being translated.

- `AshLocalize.format/1,2` — value-dispatched locale-aware formatting. Reach for
  it in Phoenix templates, LiveView, scripts, exporters, notification builders —
  anywhere you already have the value in hand. Dispatches through the upstream
  `Localize.Chars` protocol, which already covers `Integer`, `Float`, `Decimal`,
  `Date`, `Time`, `NaiveDateTime`, `DateTime`, `Range`, `List`, `Localize.Unit`,
  `Localize.Duration`, `Localize.LanguageTag`, and `Localize.Currency`. The
  `localize_address`, `localize_person_names`, and `localize_phone_number`
  satellites add their own implementations. `ash_localize` adds one more — for
  `%Money{}` from `ex_money` (the loaded value of `AshMoney.Types.Money`),
  pulling its currency from the value itself. Wrapped in `Code.ensure_loaded?/1`
  so it vanishes when the consumer has neither `ex_money` nor `ash_money` in
  their deps.

- `ash_money` is now declared as an optional dependency. With `ash_money`
  present, `AshMoney.Types.Money` is the recommended type for monetary
  attributes — see [`usage-rules.md`](usage-rules.md).

- [`usage-rules.md`](usage-rules.md) — conventions for LLM coding agents working
  with `ash_localize`. Documents the library's core stance (values carry their
  dimension), the canonical type for each modelling concept (money is `Money`,
  not split; counts are `:count`, not `:integer`; locale-like strings use the
  dedicated types), and the formatting and locale-resolution conventions.

### Changed

- `mix ash_localize.install` now registers a starting set of type short names
  rather than all of them: `:locale`, `:territory`, `:timezone`,
  `:currency_code`, `:count`, `:percentage`, `:ratio` and `:unit`. The package
  ships around thirty, and the unit categories are domain-specific — a logistics
  application wants `:mass` and `:volume`, a telemetry one wants `:acceleration`
  and `:frequency`, and neither wants the other's. The installer now prints the
  remainder as a notice instead of writing two dozen unused lines into your
  `config.exs`.

- Dependencies moved to the Localize 1.0 line, published 2026-07-30/31:
  `localize ~> 1.0` (from `~> 0.37`), `localize_person_names ~> 1.0` (from
  `~> 0.1`), `localize_address ~> 1.0` (from `~> 0.2`). No source changes were
  needed — the 1.0 API is compatible with everything `ash_localize` uses.

- `localize_phone_number` now comes from Hex at `~> 1.0` rather than a git
  reference to the old `elixir-localize/localize_phonenumber` repository. The
  package was renamed on 2026-07-31; `localize_units_sql` was absorbed into
  `localize_sql` in the same round, and references to both old names are
  corrected throughout the docs.

- `ash_money` now comes from Hex at `~> 0.2.6` rather than a git reference to
  `main`. The pin existed because the Hex release pinned `ex_money` 5.x; 0.2.6
  requires `ex_money ~> 6.0` and resolves against `ex_money` 6.2.0 and Decimal 3.

- `config :ex_money, auto_start_exchange_rate_service: false`. `ex_money` 6.2
  deprecates automatic start of the exchange rate service. `ash_localize` only
  formats `%Money{}` values, never converts them, so there is no retriever to
  start.

- `AshLocalize.Calculations.FormatCurrency` now natively accepts a `%Money{}`
  source (from [ex_money](https://hexdocs.pm/ex_money) / `AshMoney.Types.Money`)
  and pulls the currency from the value itself. This is the recommended shape —
  amount and currency stay coupled, matching this library's stance that values
  carry their dimension. `:currency` / `:currency_field` opts remain for the
  bare-number case and are ignored when the value is a `%Money{}`. `init/1` no
  longer rejects a calc declared with only `:field` (the currency may arrive at
  runtime from a Money value). New optional dependency `:ex_money ~> 6.0` —
  the `%Money{}` clause is wrapped in `Code.ensure_loaded?(Money)` and is
  absent when ex_money is not in the consumer's deps.

### Fixed

- The "optional" dependencies were not actually optional: `Localize.Address.Address`,
  `Localize.PhoneNumber.Number`, and `Localize.PersonName` struct expansions in
  pattern matches forced compile-time presence of the satellite packages, so
  `ash_localize` as a path/git dependency failed to compile unless all three were
  also declared. Each of the three satellite-backed types and their formatting
  calculations is now wrapped in a `Code.ensure_loaded?/1` guard — the module is
  defined only when its dependency is available.

### Added

- Additional CLDR scalar types:
  - `AshLocalize.Types.Timezone` — an `Ash.Type` for IANA timezone names,
    validated against CLDR's BCP 47 ↔ IANA timezone data via Localize. Accepts
    canonical IANA names, IANA aliases (`"Australia/ACT"`), or BCP 47 short
    zones (`"ausyd"`); canonicalises to the IANA name. Short name `:timezone`.
  - `AshLocalize.Types.Subdivision` — an `Ash.Type` for an ISO 3166-2
    country-subdivision code (states/provinces/regions), validated against
    `Localize.validate_territory_subdivision/1`. Optional `:territory`
    constraint pins the valid codes to subdivisions of a particular country
    (rejects `:usca` stored on a `country: :CA` row). Short name `:subdivision`.

- Phase 1 — Foundations:
  - `AshLocalize.Types.Locale`, `AshLocalize.Types.Territory`, and
    `AshLocalize.Types.CurrencyCode` custom Ash types, CLDR-validated via Localize.
  - `AshLocalize.Validations.ValidLocale`, `ValidTerritory`, and `ValidCurrencyCode`
    resource validations for plain string attributes.
  - `AshLocalize.Context.locale/2` — deterministic four-arm locale resolution.

- Phase 2 — Formatting calculations:
  - `AshLocalize.Calculations.FormatNumber`, `FormatCurrency`, `FormatDate`,
    `FormatDateTime`, and `FormatList` — locale-aware Ash calculations that render a
    source attribute as a formatted string via Localize.
  - `AshLocalize.Context.from_calculation/2` — resolves the locale from an Ash
    calculation context.

- Units of measure:
  - `AshLocalize.Types.Unit` — a dimensioned-number `Ash.Type`: the base unit is type
    metadata, the data layer stores a plain number, and the loaded value is a
    `%Localize.Unit{}` quantity. Casts and converts from any dimensionally-compatible
    unit; rejects incompatible ones.
  - Sixteen per-category types — `Length`, `Mass`, `Speed`, `Acceleration`, `Force`,
    `Volume`, `Area`, `Temperature`, `Energy`, `Power`, `Pressure`, `Angle`,
    `Frequency`, `Digital`, `ElectricCurrent`, `Voltage` — plus a `Distance` alias.
  - `AshLocalize.Calculations.FormatUnit` — locale-aware unit-of-measure formatting.

- Person names:
  - `AshLocalize.Types.PersonName` — a map-backed `Ash.Type` wrapping
    `%Localize.PersonName{}`; stored as name parts, loaded as a struct. Requires the
    optional `:localize_person_names` dependency.
  - `AshLocalize.Calculations.FormatPersonName` — locale-aware name formatting, with
    `:format`/`:usage`/`:formality`/`:order` pass-through.

- Phone numbers:
  - `AshLocalize.Types.PhoneNumber` — a string-backed (E.164) `Ash.Type`; casting
    parses and validates via libphonenumber, the loaded value is a parsed
    `%Localize.PhoneNumber.Number{}`. Requires the optional `:localize_phone_number`
    dependency.
  - `AshLocalize.Calculations.FormatPhone` — `:international`/`:national`/`:e164`/
    `:rfc3966` formatting.

- Postal addresses:
  - `AshLocalize.Types.PostalAddress` — a map-backed `Ash.Type` wrapping
    `%Localize.Address.Address{}`. Requires the optional `:localize_address` dependency.
  - `AshLocalize.Calculations.FormatAddress` — locale-aware, multi-line address
    formatting.

- Extensibility:
  - `AshLocalize.UnitType` — the macro that generates the 16 built-in per-category
    unit types is now public, with `:category` optional. Users can define their own
    dimensioned types (compound units such as *jerk* / `meter-per-cubic-second`, or
    anything registered with `Localize.Unit.CustomRegistry`) with a one-line `use`.
  - `AshLocalize.UnitType.defunit/2` — a `defunit Name, base_unit: "..."` shortcut
    that expands to the `defmodule … use AshLocalize.UnitType, …` form.

- Igniter installers:
  - `mix igniter.install ash_localize` — sets `config :ash_localize, default_locale`,
    registers the scalar and unit-category short names, and detects any optional
    satellites (`localize_person_names`, `localize_phone_number`, `localize_address`)
    already in the consumer's deps and registers their types too.
  - `mix ash_localize.gen.unit_type ModuleName --base-unit ... [--category ...]
    [--short-name foo]` — scaffolds a custom unit type via `AshLocalize.UnitType`
    and optionally registers a short name.
  - `igniter` is now an optional dependency.

- Numeric semantic types (Tier 1 — completes the numeric-types modelling):
  - `AshLocalize.Types.Count` — non-negative integer + `:of` semantic tag, plus
    `:min` / `:max` / `:zero?` constraints. `AshLocalize.Calculations.FormatCount`
    renders plural-aware via MF2 with simple `:if_zero` / `:one` / `:other` …
    forms or a raw `:template`. `:of` is the key the future translation catalogue
    will use to drive locale-specific templates (Japanese counter words, etc.).
  - `AshLocalize.Types.Ordinal` + `FormatOrdinal` — RBNF: `1` → `"1st"` (en),
    `"1er"` (fr), `"第1"` (ja).
  - `AshLocalize.Types.Percentage` + `FormatPercent` — `Decimal`-backed, bounded
    `0..1` by default; renders `"75%"`.
  - `AshLocalize.Types.Ratio` + `FormatRatio` — `Decimal` 0..1; renders the vulgar
    fraction `"3⁄4"`.
  - `AshLocalize.Types.Score` + `FormatScore` — open-bounded `Decimal` score with
    optional `:min` / `:max`; renders with locale-correct separators.
  - `AshLocalize.Types.Rating` + `FormatRating` — `Decimal` with required `:out_of`;
    renders `"X / Y"` by default or a plural-aware sentence with MF2 forms.
  - Short names (`:count`, `:ordinal`, `:percentage`, `:ratio`, `:score`,
    `:rating`) registered automatically by `mix igniter.install ash_localize`.
  - [Custom units guide](documentation/custom_units.md) covers the three patterns
    (compound units, reusable custom types, `CustomRegistry`).
