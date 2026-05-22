# ash_localize — design plan

Draft for collaborator review. Reasonable assumptions noted inline; open questions for Kip listed at the end. Nothing here is locked.

## Status

Implemented and on `main`:

- **Phase 1 — Foundations** (`a910c71`). `Locale`, `Territory`, `CurrencyCode` types; validations; `AshLocalize.Context`; default config.
- **Phase 2 — Formatting calculations** (`5deadfd`). `format_number`, `format_currency`, `format_date`, `format_datetime`, `format_list`.
- **Units of measure** (`224b8e1`). Brought forward from Phase 5 and reshaped — see below.

The units design changed during implementation. Rather than one generic `Unit` type storing `{value, unit}`, units are **per-category types** (`Speed`, `Mass`, `Length`, …) over a shared engine: the unit is type metadata, the column stores a plain number in the category's base unit, and the loaded value is a `%Localize.Unit{}`. This keeps data-layer aggregates and sorting native, with no composite type. The sections below are updated to match.

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

## Package layout

Three packages, each shippable independently. Matches the `ash_authentication` / `ash_authentication_phoenix` split rather than the older single-package `ash_money` pattern. Justification:

1. Localize has no SQL-helper companion analogous to `ex_money_sql`; bundling Postgres support into the core would mean writing and maintaining that plumbing inside the same package that's also the data-layer-agnostic core. Cleaner as a separate add-on.
2. Most of what `ash_localize` does — type casting, validation, format calculations, locale context, translation lookup — is data-layer-agnostic. Splitting keeps the dep graph clean for AshSqlite / AshEts / AshMnesia users.
3. The Phoenix/LiveView bridge has its own deps (`ash_phoenix`, `localize_web`, `localize_*_inputs`) and a different audience from headless API users.

### `ash_localize` (core)

Data-layer-agnostic. Default storage for every custom type is plain primitives or maps. Works on AshPostgres, AshSqlite, AshEts, AshMnesia without modification. Postgres-native optimisations live in the add-on.

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
```

Compile-time registration for short type names:

```elixir
config :ash, :custom_types,
  locale: AshLocalize.Types.Locale,
  currency: AshLocalize.Types.Currency,
  localized_string: AshLocalize.Types.LocalizedString,
  phone_number: AshLocalize.Types.PhoneNumber
```

### `ash_localize_postgres`

Thin AshPostgres add-on. Installed via repo `installed_extensions/0`, `ash_money` pattern.

Provides:

- Native composite-type lowering for `Currency`, `PhoneNumber`, `PersonName` where it unlocks query power. Default JSONB storage for `LocalizedString` and `PostalAddress`. (`Unit` needs none — it is already a plain numeric column.)
- Migration generator for the composite types.
- `COLLATE "und-x-icu"`-style fragments for locale-aware sort (`sort: expr(localize_collate(name, "ja"))`).
- JSONB query helpers for filtering `LocalizedString` attributes by locale.
- Currency aggregation is deferred to `ash_money` where applicable. Unit aggregation needs no add-on: a unit attribute stores a plain number in a fixed base unit, so `sum`/`avg` work natively on every data layer.

No new primitives. Pure optimisation layer.

### `ash_localize_phoenix`

Bridges Ash resources to the broader elixir-localize web/UI stack.

Provides:

- `AshLocalize.Phoenix.LocalePlug` — one-line wrapper around `localize_web`'s negotiation plug that copies the resolved locale into Ash context (`Ash.set_context(%{locale: locale})`) for the request lifecycle.
- `AshLocalize.Phoenix.Form` — helpers that render the appropriate `localize_inputs_*` component for a given Ash type. `<.ash_input field={f[:price]} />` inspects the type and emits `<.number_input>` with currency formatting; for `LocalizedString`, emits a tabbed multi-locale input.
- `AshPhoenix.Form` integration for translated attributes — submitting a form with multiple locales produces the right changeset structure for the configured translation store.

Depends on `ash_phoenix`, `localize_web`, and the `localize_inputs_*` packages.

## Type system

Each custom type is implemented as `Ash.Type` and routes casting/validation through Localize. Default storage representations:

| Type             | Default storage              | PG-native (via add-on)                |
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

Two integration points, both in `ash_localize_phoenix`. Composition over duplication — the `localize_inputs_*` family already ships a coherent, locale-aware component set with shared CSS tokens, Gettext catalogue, and structured validation errors. Building parallel components forks the visual and behavioural story.

**1. Request locale → Ash context.**

```elixir
plug AshLocalize.Phoenix.LocalePlug
```

Wraps `localize_web`'s negotiation plug and writes the resolved locale into Ash context for downstream operations.

**2. Form rendering.**

```heex
<.ash_input field={@form[:price]} />          <!-- Currency → number_input w/ currency formatting -->
<.ash_input field={@form[:event_date]} />     <!-- Date → date_input -->
<.ash_input field={@form[:description]} />    <!-- LocalizedString → tabbed multi-locale input -->
```

The renderer is a thin component that reads the Ash type from the form field and delegates to the matching `localize_inputs_*` component. For `LocalizedString`, we render one input per configured locale with a tab UI built from `localize_inputs_core`'s tokens; the changeset gathers all submitted locales.

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
| Composite type storage      | Native (via add-on)          | JSON                     | Map              |
| Locale-aware sort           | ICU collation fragment       | Best-effort, Elixir-side | Elixir-side      |
| Aggregate sum-of-units      | Native (plain column)        | Native (plain column)    | Native           |
| Migration generation        | Via add-on                   | n/a                      | n/a              |

Core works on all four. `ash_localize_postgres` layers optimisations onto AshPostgres. SQLite support could ship as a small `ash_localize_sqlite` if demand emerges; deferred.

## Build phases

Phased by user-visible value, not by module dependency order.

1. **Foundations.** `Locale`, `Territory`, `CurrencyCode` types; validations; `AshLocalize.Context.locale/2`; default config. Smallest useful slice; immediately unblocks resources that need validated locale-shaped fields.
2. **Formatting calculations.** `format_number`, `format_currency`, `format_date`, `format_datetime`, `format_list`. Locale-aware read-side formatting on top of the resolution chain.
3. **Translations: `Embedded` store.** `LocalizedString` type + DSL + Embedded store + per-field localized calculations + form-friendly write argument handling. Minimum viable translation story.
4. **Translations: `SiblingResource` store.** Spark transformer that generates the sister resource. Opt-in alternative for apps that need translation workflows, filter-by-translated-text in Ash expressions, or a smoother migration path to `LocalizeTranslate`.
5. **Composite domain types.** `PhoneNumber`, `PersonName`, `PostalAddress`, with their format calcs. (`Unit` — reshaped as per-category types — and `format_unit` are already done; see Status.)
6. **`ash_localize_postgres`.** Composite lowering, collation fragments, JSONB helpers, migration generator.
7. **`ash_localize_phoenix`.** `LocalePlug` + `<.ash_input>` + multi-locale form handling.
8. **`LocalizeTranslate` adapter.** Lands once the upstream interface is stable.
9. **ash_graphql / ash_json_api registrations.** Could move earlier if a consumer needs it.

Phases 1–3 are the minimum useful set. Phases 4–7 are production-grade.

## Open questions for Kip

(Plan proceeds on assumptions noted below; these are confirmations, not blockers.)

1. **`localize_translate` interface shape.** Plan assumes a public behaviour we can adapter against. If the surface is purely Ecto-schema-coupled, the `LocalizeTranslate` adapter is AshPostgres-only and we document that. `Embedded` and `SiblingResource` remain available everywhere else. Is the behaviour-shaped interface workable, or is the Ecto coupling permanent?
2. **MessageFormat 2 catalogue conventions.** When `ash_localize` emits MF2-formatted strings (default validation error messages, format-calc captions), what key/namespace should they live under in a catalogue? Plan assumes `ash_localize.<context>.<key>`; happy to align with whatever `localize_translate` uses.
3. **Composite-type stability in PG.** Native PG composite types have historically been rough in Ecto. AshPostgres has improved here; worth confirming current state before committing the PG add-on to native composites for `PhoneNumber` / `PersonName` rather than JSONB.
4. **Elixir-side collator.** Does Localize expose (or plan to expose) a stable locale-aware string comparator usable from SQLite/ETS sort paths, or do we delegate to `:unicode_util`?
5. **The "unpublished" translation work.** Whether that's a new iteration of `localize_translate`, a sibling, or something else — affects which package we adapter against in phase 8.

## Assumptions made to keep moving

- `localize_translate` is the intended upstream translation store; `ash_localize` ships its own behaviour and adapter rather than coupling directly. Two non-upstream stores (`Embedded`, `SiblingResource`) provide fallback coverage.
- `Embedded` is the recommended default store: simplest mental model, one fetch returns all translations, works on every data layer. `SiblingResource` is opt-in for apps that genuinely need workflow, filter-by-translated-text in Ash expressions, or cleaner alignment with `LocalizeTranslate`. Caveat: if most users end up migrating to `LocalizeTranslate`-backed storage, `Embedded`-default users will face a data-shape migration. Worth tracking; acceptable trade for simplicity now.
- Three packages: `ash_localize`, `ash_localize_postgres`, `ash_localize_phoenix`. Modern ecosystem split.
- LiveView story is composition, not duplication: `localize_inputs_*` is dispatched from a single `<.ash_input>` helper.
- Default `LocalizedString` GraphQL shape is "object with per-locale fields"; configurable to JSON scalar.
- Locale resolution chain has exactly four arms. Actor inference is opt-in. Process dict is excluded. Tenant inference is excluded.
- Composite types default to map/JSON storage; Postgres-native lowering is a pure optimisation in the add-on.
- Naming: `ash_localize`, US spelling, matching upstream.