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
