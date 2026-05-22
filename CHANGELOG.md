# Changelog

All notable changes to this project are documented here.

## [Unreleased]

### Added

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
