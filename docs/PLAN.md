# ash_localize — design plan

Draft for collaborator review. Reasonable assumptions noted inline; open questions for upstream listed at the end. Nothing here is locked.

## Status

Implemented and on `main`:

- **Foundations** (`a910c71`). `Locale`, `Territory`, `CurrencyCode` types; validations; `AshLocalize.Context`; default config.
- **Formatting calculations** (`5deadfd`). `format_number`, `format_currency`, `format_date`, `format_datetime`, `format_list`.
- **Composite domain types.** `Unit` (`224b8e1`), `PersonName` (`eb55a58`), `PhoneNumber` and `PostalAddress` (`2b02af1`) — each with its formatting calculation.

Still to come: the optional Postgres and Phoenix integrations, the GraphQL / JSON:API registrations, and translations — sequenced last by choice. See Build phases.

Two designs changed during implementation. **Units** became **per-category types** (`Speed`, `Mass`, `Length`, …) over a shared engine, rather than one generic `Unit` storing `{value, unit}`: the unit is type metadata, the column stores a plain number in the base unit, and the loaded value is a `%Localize.Unit{}` — keeping data-layer aggregates native. And the **package layout** collapsed from three packages to one with optional dependencies. The sections below reflect both.

## Context

`ash_localize` is the Ash framework integration for [Localize](https://github.com/elixir-localize/localize), the next-generation CLDR-backed localization library for Elixir (successor to ex_cldr). Its job is to make Ash resources locale-aware at the resource level: CLDR-validated typed attributes, locale-aware formatting as calculations, translatable string fields, and clean composition with the broader elixir-localize ecosystem (`localize_web`, the `localize_*_inputs` LiveView family, `localize_translate`, `calendrical`).

Naming follows upstream and Ash convention: `ash_localize` (US spelling, matching `localize`).

## Goals

- Resources can declare attributes whose types are CLDR-validated (locale, territory, currency code, unit, phone, person name, address) and CLDR-aware in formatting.
- Locale-aware formatting available as built-in Ash calculations, with locale resolved from a single deterministic chain.
- Translatable attributes on resources, with a pluggable storage backend so we can adapt to `localize_translate` (or its successor) without breaking the resource-level API.
- Clean composition with `localize_web` (HTTP layer) and the `localize_*_inputs` LiveView components (form UI) via a thin Phoenix bridge.
- Optional native-Postgres optimisations as a separate package; core is data-layer-agnostic.

## Non-goals

- Re-exporting Localize's plain functional API behind `AshLocalize.*`. If you have a number and a locale, call `Localize.Number.format/2`.
- Owning HTTP locale negotiation — that lives in `localize_web`.
- Building new LiveView input components — the `localize_inputs_*` family already covers it.
- Shipping a translation catalogue, `.po` pipeline, or extraction tooling — upstream's domain.
- Tenant-coupled locale inference. Apps can opt in via the actor extractor.
- Generic "useful types every app needs." `lat_long`, `color`, `url`, `path`, `email`, `api_key`, `jwt`, `ulid`, `slug`, `probability`, `year`, `age` and similar are not CLDR-flavoured — they belong in a separate **`ash_common_types`** package (TBD). `un_locode` is a heavyweight reference-data type (~110K UNECE codes, biannual updates, logistics-domain) and belongs in its own **`ash_logistics`** (or similar) package atop an as-yet-unwritten Elixir LOCODE dataset. ash_localize stays scoped to CLDR + the elixir-localize ecosystem.

## Package layout

One package: `ash_localize`. The elixir-localize ecosystem is a hub — `localize` — surrounded by satellites (`localize_phone_number`, `localize_address`, `localize_person_names`, `localize_translate`, `localize_sql`, `localize_web`, the `localize_*_inputs` family). `ash_localize` provides the Ash integration for the whole ecosystem from one package; the heavy satellites are **optional dependencies**.

- `localize` is the only hard dependency — the CLDR hub (numbers, dates, units, lists, territories, languages, collation, MessageFormat), pure Elixir plus data.
- Every other satellite, and `ash_postgres` / `ash_phoenix`, is declared `optional: true`: it — and its native baggage, such as libpostal or libphonenumber — is compiled in only when the consuming application also declares it. The application's dependency list is the feature switch.

Each optional integration sits behind a `Code.ensure_loaded?/1` compile guard, the pattern already used for the ash_graphql / ash_json_api registrations below, so the package compiles and runs with none present. An attribute or calculation needing an absent satellite fails loudly, naming the package to add.

This supersedes an earlier three-package split (`ash_localize` / `_postgres` / `_phoenix`). That split's main argument was that Localize had no SQL companion to lean on — but `localize_sql` exists, the Phoenix bridge is small, and optional dependencies keep one package, for a consumer who opts into nothing, as light as a split one.

### Core

Data-layer-agnostic. Default storage for every custom type is plain primitives, numbers, or maps. Works on AshPostgres, AshSqlite, AshEts, AshMnesia without modification.

```
lib/ash_localize.ex                       # entry, config, version
lib/ash_localize/context.ex               # locale resolution
lib/ash_localize/types/
  locale.ex
  territory.ex
  currency_code.ex
  currency.ex                             # {amount, currency_code}
  unit.ex                                 # dimensioned-number engine
  unit_categories.ex                      # per-category types: Speed, Mass, …
  phone_number.ex                         # E.164 string + metadata
  person_name.ex                          # composite name parts
  postal_address.ex                       # via localize_address
  localized_string.ex                     # %{locale => string}
lib/ash_localize/calculations/
  format_number.ex
  format_currency.ex
  format_date.ex
  format_datetime.ex
  format_interval.ex
  format_unit.ex
  format_list.ex
  format_phone.ex
  format_person_name.ex
  format_address.ex
  translate.ex                            # resolves a translation key
lib/ash_localize/validations/
  valid_locale.ex
  valid_currency_code.ex
  valid_territory.ex
  valid_unit.ex
lib/ash_localize/translations/
  extension.ex                            # Spark DSL extension
  store.ex                                # behaviour
  stores/
    embedded.ex                           # LocalizedString in-row
    sibling_resource.ex                   # generated translations resource
    localize_translate.ex                 # adapter
lib/ash_localize/integrations/
  ash_graphql.ex                          # type registrations, guarded
  ash_json_api.ex                         # type registrations, guarded
lib/ash_localize/postgres/                # optional: ash_postgres + localize_sql
  composite_types.ex
  migrations.ex
lib/ash_localize/phoenix/                 # optional: ash_phoenix + localize_web
  locale_plug.ex
  form.ex
```

Compile-time registration for short type names:

```elixir
config :ash, :custom_types,
  locale: AshLocalize.Types.Locale,
  currency: AshLocalize.Types.Currency,
  localized_string: AshLocalize.Types.LocalizedString,
  phone_number: AshLocalize.Types.PhoneNumber
```

### Postgres optimisations (optional)

Active when `ash_postgres` and `localize_sql` are present; installed via repo `installed_extensions/0`, `ash_money` pattern.

Provides:

- Native composite-type lowering for `Currency`, `PhoneNumber`, `PersonName` where it unlocks query power. Default JSONB storage for `LocalizedString` and `PostalAddress`. (`Unit` needs none — it is already a plain numeric column.)
- Migration generator for the composite types.
- `COLLATE "und-x-icu"`-style fragments for locale-aware sort (`sort: expr(localize_collate(name, "ja"))`).
- JSONB query helpers for filtering `LocalizedString` attributes by locale.
- Currency aggregation is deferred to `ash_money` where applicable. Unit aggregation needs no add-on: a unit attribute stores a plain number in a fixed base unit, so `sum`/`avg` work natively on every data layer.

No new primitives. Pure optimisation layer.

### Phoenix bridge (optional)

Active when `ash_phoenix`, `localize_web`, and the `localize_*_inputs` family are present. Bridges Ash resources to the elixir-localize web/UI stack.

Provides:

- `AshLocalize.Phoenix.LocalePlug` — one-line wrapper around `localize_web`'s negotiation plug that copies the resolved locale into Ash context (`Ash.set_context(%{locale: locale})`) for the request lifecycle.
- `AshLocalize.Phoenix.Form` — helpers that render the appropriate `localize_inputs_*` component for a given Ash type. `<.ash_input field={f[:price]} />` inspects the type and emits `<.number_input>` with currency formatting; for `LocalizedString`, emits a tabbed multi-locale input.
- `AshPhoenix.Form` integration for translated attributes — submitting a form with multiple locales produces the right changeset structure for the configured translation store.

These components are guarded — absent those packages, the bridge compiles to nothing.

## Type system

Each custom type is implemented as `Ash.Type` and routes casting/validation through Localize. Default storage representations:

| Type             | Default storage              | PG-native (optional)                  |
|------------------|------------------------------|---------------------------------------|
| `Locale`         | string                       | string                                |
| `Territory`      | string                       | string                                |
| `CurrencyCode`   | string                       | string                                |
| `Currency`       | map `{amount, currency}`     | composite type                        |
| `Unit` (per category) | number, in the base unit | number (plain numeric column)         |
| `PhoneNumber`    | string (E.164)               | composite type w/ metadata            |
| `PersonName`     | map                          | composite type                        |
| `PostalAddress`  | map                          | JSONB                                 |
| `LocalizedString`| map `%{locale => string}`    | JSONB                                 |

The default representation works on every data layer. Lowering to composite types is purely an optimisation that unlocks queryability and aggregates in AshPostgres. Units are the exception in the table above: a unit value is already a plain number in its base unit, so there is nothing to lower and aggregates are native everywhere.

## Locale resolution

One function, one chain. Used by every calculation, validation, change, and store adapter that needs a locale.

```elixir
AshLocalize.Context.locale(arg, opts) :: {:ok, locale} | {:error, :no_locale}
```

Precedence, most specific to least:

1. **Explicit calculation/action argument.** `Ash.read!(query, arguments: %{locale: "ja-JP"})`, or a calc declaring a `locale` argument. Always wins.
2. **Ash context `:locale` key.** Set per-operation: `Ash.read!(query, context: %{locale: "ja-JP"})` or `Ash.set_context(%{locale: ...})` upstream of the call. Wins over actor because users can deliberately operate in a non-native locale (translators previewing, support admins).
3. **Actor-derived locale.** Off by default. Opt-in via `actor_locale: {Mod, :fun}` or a 1-arg function applied to `context.actor`. Surfacing it as an explicit flag forces a conscious choice.
4. **Application default.** `config :ash_localize, default_locale: "en"`. Raised loudly at startup if unset; never silently `nil`.

Explicitly excluded from the chain:

- **Process dictionary** (`Localize.put_locale/1`). Reading from pdict inside Ash creates spooky action across calculations and aggregates that may run in different processes (especially with parallel loads). Users who want pdict behaviour bridge it in their plug by copying into Ash context. Keeping the resolver pure removes a class of "why is this calc English in tests" bugs.
- **Tenant.** Some apps tie locale to tenant; if so, they wire it via the actor extractor or a context middleware. Putting it in the core resolver privileges a pattern that isn't universal.

Context propagation:

- `:locale` is registered in the resource's `context_to_load_opts` so it survives `Ash.Query.load/2` into related-resource calculations.
- Background jobs must carry locale in their args and call `Ash.set_context/2` before invoking actions. Documented in a guide page rather than handled automatically — pdict-based smuggling would reintroduce the problems above.

## Translations

Resource-level DSL extension, backend-agnostic.

```elixir
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    domain: MyApp.Catalog,
    extensions: [AshLocalize.Translations]

  translations do
    translate :name, :description
    store {AshLocalize.Translations.Stores.Embedded, []}
    fallback_chain [:requested, :default]
  end
end
```

Built-in stores:

- **`Embedded`** — translations stored in a `LocalizedString` attribute on the resource itself. One resource, one fetch returns all translations, no join, no preload. The recommended default: simplest mental model, simplest operations, and works on every data layer. JSONB on Postgres is indexable via expression indexes if filter-by-translated-text becomes a need.
- **`SiblingResource`** — Spark transformer auto-generates `MyApp.Catalog.ProductTranslation` with a `(product_id, locale)` identity, one row per translation. Opt in when you need filter-by-translated-text inside Ash's typed expression DSL (`exists(translations, locale == "es" and contains(name, ...))`), per-translation workflow state, per-locale permissions, ash_paper_trail-tracked translation history, or concurrent editing across locales without row contention.
- **`LocalizeTranslate`** — adapter to upstream `localize_translate`. Activated when the package is available. Likely row-per-(entity, locale) shape, so users on `SiblingResource` have a cleaner migration path than users on `Embedded` if they want to move.

Behaviour contract (subject to upstream alignment):

```elixir
@callback get_translation(key :: term, locale :: String.t, opts :: keyword) ::
            {:ok, String.t} | {:error, term}
@callback put_translation(key :: term, locale :: String.t, value :: String.t, opts :: keyword) ::
            :ok | {:error, term}
@callback list_locales(key :: term, opts :: keyword) :: [String.t]
@callback default_locale() :: String.t
```

Reads:

- Per declared field, a calculation is auto-generated: `:name_localized` resolves via the store using the current locale and fallback chain. The underlying storage attribute remains accessible.

Writes:

- Action arguments accept either a single string (writes to the requested locale) or a `%{locale => string}` map (writes multiple). Validation errors are returned per locale.

Fallback chain semantics:

- `:requested` — the resolved locale.
- `:default` — the application default.
- `:any` — first available, deterministic order.
- Explicit locales also accepted: `[:requested, "en", :any]`.

## Phoenix and LiveView

The bridge is three pieces, all inside the optional Phoenix integration. Composition over duplication — the `localize_inputs_*` family already ships a coherent, locale-aware component set with shared CSS tokens, Gettext catalogue, and structured validation errors. Parallel components would fork the visual and behavioural story.

### Upstream readiness

The full ecosystem the bridge depends on is published, and the Localize half went 1.0 on 2026-07-31:

| Package                    | Hex    | Provides                                                                                |
|----------------------------|--------|-----------------------------------------------------------------------------------------|
| `ash_phoenix`              | 2.3.24 | Ash ↔ Phoenix glue, `AshPhoenix.Form`                                                   |
| `localize_web`             | 1.0.0  | HTTP locale negotiation plug, localized routes, HTML helpers                            |
| `localize_inputs_core`     | 0.2.0  | Shared CSS tokens, Gettext backend, JS bootstrap                                        |
| `localize_datetime_inputs` | 0.2.0  | `<.date_input>`, `<.date_range_input>`, `<.date_range_picker>`, multi-calendar support  |
| `localize_number_inputs`   | 0.2.0  | `<.number_input>` (decimal/integer), `<.unit_input>` (number + UoM picker)              |
| `ex_money_input`           | 0.3.0  | `<.money_input>` — amount + currency, parsed in-locale                                  |

There is no `localize_inputs` umbrella on Hex — the family ships as the per-flavour packages above.

### 1. Request locale → Ash context

```elixir
plug AshLocalize.Phoenix.LocalePlug
```

Wraps `localize_web`'s negotiation plug and copies the resolved locale into Ash context (`Ash.set_context(%{locale: ...})`) for downstream operations. Arm 2 of the locale resolution chain then sees it on every action in the request.

### 2. `<.ash_input>` dispatcher

One component reads the Ash type of a form field and emits the right widget. The form author writes one component; the locale-correct input appears.

```heex
<.simple_form for={@form}>
  <.ash_input field={@form[:delta_v]} />          <!-- :speed → <.unit_input>           -->
  <.ash_input field={@form[:completion]} />       <!-- :percentage → <.number_input>    -->
  <.ash_input field={@form[:start_at]} />         <!-- :utc_datetime → datetime input   -->
  <.ash_input field={@form[:billing_currency]} /> <!-- :currency_code → currency select -->
  <.ash_input field={@form[:description]} />      <!-- LocalizedString → tabs           -->
</.simple_form>
```

Dispatch table:

| Ash type                                       | Component                                  | Source                     |
|------------------------------------------------|--------------------------------------------|----------------------------|
| `:unit`, `:speed`, `:mass`, `:length`, …       | `<.unit_input>`                            | `localize_number_inputs`   |
| `:count`, `:ordinal`                           | `<.number_input>` (integer)                | `localize_number_inputs`   |
| `:percentage`, `:ratio`, `:score`, `:rating`   | `<.number_input>` (decimal)                | `localize_number_inputs`   |
| `:date`, `:utc_datetime`, `:naive_datetime`    | date / datetime input                      | `localize_datetime_inputs` |
| `:locale`, `:territory`, `:currency_code`      | select on CLDR data (flags / symbols)      | **`ash_localize` builds**  |
| `:phone_number`                                | `<input type="tel">` with E.164 hint       | **`ash_localize` builds**  |
| `:postal_address`                              | per-country address form (template-driven) | **`ash_localize` builds**  |
| `:person_name`                                 | per-locale name-field order                | **`ash_localize` builds**  |
| `LocalizedString` *(Phase 7)*                  | tabbed multi-locale input                  | **`ash_localize` builds**  |

Six rows are upstream-covered; six are small components `ash_localize` builds on top of `localize_inputs_core`'s tokens; two need Phase 7 first.

### 3. `AshPhoenix.Form` for multi-locale fields (Phase 7)

For `LocalizedString` fields, the form gathers per-locale values via a tabbed input; on submit, the changeset structure matches the configured translation store. Lands when translations land.

### Stages

Three commit-sized stages, in order:

1. **Plug + dispatcher skeleton.** `LocalePlug`; `<.ash_input>` for the upstream-covered types (units, numbers, dates). The Phoenix/LiveView test setup (`Phoenix.LiveViewTest`, a thin test endpoint) arrives with this stage and unblocks the rest.
2. **Selects and component-light types.** Locale, territory, and currency_code selects (CLDR data with flags and display names); `<input type="tel">` for phone; basic `:postal_address` and `:person_name` field forms.
3. **Multi-locale forms.** Tabbed `<.ash_input>` for `LocalizedString` and `AshPhoenix.Form` write handling. Depends on Phase 7.

## GraphQL and JSON:API

Type registrations live in `ash_localize` core under `if Code.ensure_loaded?(...)` guards so they don't drag deps into projects that don't use those extensions. Pattern follows ash_money.

- `LocalizedString` → GraphQL object with per-locale fields, or a JSON scalar. Configurable.
- `Currency` → object `{ amount, currencyCode, formatted }` where `formatted` uses the request locale.
- `PhoneNumber` → string (E.164) with an optional `formatted` field.
- Composite types serialize to their underlying maps in JSON:API by default.

## Data-layer matrix

| Concern                     | AshPostgres                  | AshSqlite                | AshEts/Mnesia    |
|-----------------------------|------------------------------|--------------------------|------------------|
| LocalizedString filter      | JSONB query (helper)         | JSON1 query              | In-memory        |
| Composite type storage      | Native (optional)            | JSON                     | Map              |
| Locale-aware sort           | ICU collation fragment       | Best-effort, Elixir-side | Elixir-side      |
| Aggregate sum-of-units      | Native (plain column)        | Native (plain column)    | Native           |
| Migration generation        | Built-in (Postgres)          | n/a                      | n/a              |

Works on all four. The optional Postgres integration layers its optimisations onto AshPostgres. Deeper SQLite-specific support is deferred until there is demand.

## Build phases

Phased by user-visible value. Translations are deliberately sequenced last.

**Done** — see Status for commits:

1. **Foundations.** `Locale`, `Territory`, `CurrencyCode` types; validations; `AshLocalize.Context.locale/2`; default config.
2. **Formatting calculations.** `format_number`, `format_currency`, `format_date`, `format_datetime`, `format_list`.
3. **Composite domain types.** `Unit` (per-category), `PhoneNumber`, `PersonName`, `PostalAddress`, each with its format calculation.

**Remaining**, in order:

4. **Postgres optimisations.** Composite lowering, collation fragments, JSONB helpers, migration generator. Optional; needs `ash_postgres` + `localize_sql`.
5. **Phoenix bridge** (three stages). `LocalePlug`, `<.ash_input>` dispatcher, and multi-locale form handling. Optional; needs `ash_phoenix` + `localize_web` + the `localize_*_inputs` family. See Phoenix and LiveView for the stage breakdown.
6. **ash_graphql / ash_json_api registrations.** Guarded type registrations for projects using those extensions.
7. **Translations: `Embedded` store.** `LocalizedString` type + Spark DSL extension + Embedded store + per-field localized calculations + form-friendly write handling. The minimum viable translation story.
8. **Translations: `SiblingResource` store.** Spark transformer that generates the sister translations resource. Opt-in alternative for apps that need translation workflows, filter-by-translated-text in Ash expressions, or a cleaner migration path to `LocalizeTranslate`.
9. **`LocalizeTranslate` adapter.** Lands once the upstream interface is stable.

## Open questions for upstream

(Plan proceeds on assumptions noted below; these are confirmations, not blockers.)

1. **`localize_translate` interface shape.** Plan assumes a public behaviour we can adapter against. If the surface is purely Ecto-schema-coupled, the `LocalizeTranslate` adapter is AshPostgres-only and we document that. `Embedded` and `SiblingResource` remain available everywhere else. Is the behaviour-shaped interface workable, or is the Ecto coupling permanent?
2. **MessageFormat 2 catalogue conventions.** When `ash_localize` emits MF2-formatted strings (default validation error messages, format-calc captions), what key/namespace should they live under in a catalogue? Plan assumes `ash_localize.<context>.<key>`; happy to align with whatever `localize_translate` uses.
3. **Composite-type stability in PG.** Native PG composite types have historically been rough in Ecto. AshPostgres has improved here; worth confirming current state before committing the Postgres integration to native composites for `PhoneNumber` / `PersonName` rather than JSONB.
4. **Elixir-side collator.** Does Localize expose (or plan to expose) a stable locale-aware string comparator usable from SQLite/ETS sort paths, or do we delegate to `:unicode_util`?
5. **The "unpublished" translation work.** Whether that's a new iteration of `localize_translate`, a sibling, or something else — affects which package the `LocalizeTranslate` adapter targets.

## Assumptions made to keep moving

- `localize_translate` is the intended upstream translation store; `ash_localize` ships its own behaviour and adapter rather than coupling directly. Two non-upstream stores (`Embedded`, `SiblingResource`) provide fallback coverage.
- `Embedded` is the recommended default store: simplest mental model, one fetch returns all translations, works on every data layer. `SiblingResource` is opt-in for apps that genuinely need workflow, filter-by-translated-text in Ash expressions, or cleaner alignment with `LocalizeTranslate`. Caveat: if most users end up migrating to `LocalizeTranslate`-backed storage, `Embedded`-default users will face a data-shape migration. Worth tracking; acceptable trade for simplicity now.
- One package, `ash_localize`. Satellites (`localize_address`, `localize_phone_number`, …) and the Postgres / Phoenix integrations are optional dependencies, guarded so they cost nothing when absent.
- LiveView story is composition, not duplication: `localize_inputs_*` is dispatched from a single `<.ash_input>` helper.
- Default `LocalizedString` GraphQL shape is "object with per-locale fields"; configurable to JSON scalar.
- Locale resolution chain has exactly four arms. Actor inference is opt-in. Process dict is excluded. Tenant inference is excluded.
- Composite types default to map/JSON storage; Postgres-native lowering is a pure optimisation in the optional Postgres integration.
- Naming: `ash_localize`, US spelling, matching upstream.