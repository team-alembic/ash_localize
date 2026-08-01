# Localize and Ash: an integrated plan

Based upon the initial plan built by Alembic to reflect a potentially broader scope and proposing answers to the five open questions in the original plan.

## Scope

The `ash_localize` original plan covers the resource level: CLDR-validated Ash types, locale-aware formatting as calculations, and a deterministic locale-resolution chain. It was built deliberately without requiring any change to Ash, which is what made it shippable — and which also sets its ceiling.

What sits above that ceiling needs Ash core: a display callback, a parse callback, locale propagation into async work, and collation in sorting. Those are the substance of Parts III and IV.

## Architectural principle

**Localization is a boundary concern, not a storage concern.** The data layer stores canonical values — `Decimal`, `Date`, UTC `DateTime`, an atom currency code, a number in a base unit. Localization applies on the way out (render) and on the way in (parse). Serialization formats aimed at machines — JSON:API, GraphQL scalars, `ash_typescript` — keep emitting canonical values; localized display is an *additional*, explicitly-requested field, never a substitution.

Conflating the two is how `"1.234,5"` ends up in a database column. Any proposal that makes an attribute *store* a localized string should be rejected. The exception is genuinely translated content — a product name per language — which is a modelling problem, and which `ash_localize` already handles as one.

Both projects arrived at this independently. `ash_localize`'s non-goals state it as "if you have a number and a locale, call `Localize.Number.format/2`", and its unit types store a plain number in a base unit precisely so data-layer aggregates stay native. It is shared ground rather than something either side needs to argue for.

## The Localize packages

What the integration draws on already exists as published packages, which is why most of what remains is integration work rather than new capability.

| Package | Provides | Relevant to |
|---|---|---|
| `localize` 1.0 | CLDR core — numbers, dates, units, lists, collation, MF2, 766 locales, no compile-time backend | everything |
| `calendrical` 1.0 | Locale-aware date/time/interval **parsing**, 17 CLDR calendar systems, fiscal years | `cast_input`, non-Gregorian types |
| `localize_sql` 1.0 | ICU `COLLATE` via CLDR language matching on PostgreSQL and SQLite, collation migrations, and Ecto types for units, currencies, language tags, territories, scripts, ranges and durations | `ash_postgres`, `ash_sqlite`, `ash_sql`, sorting, the composite types |
| `localize_web` 1.0 | `Accept-Language` / session / cookie / TLD locale plugs, localized routing (`~q`), localized `<select>` helpers | `ash_phoenix`, `ash_admin` |
| `localize_number_inputs`, `localize_datetime_inputs`, `ex_money_input` | LiveView components that format *and parse* in-locale, multi-calendar date pickers | `AshPhoenix.Form`, `ash_admin` forms |
| `localize_translate` 0.2 | Translated content on the record, with a pluggable store behaviour — embedded and sibling-row implementations | the `Translations` DSL and its stores |
| `ex_money` 6.2, `ex_money_sql` 2.1 | Money, Localize-backed, with database-side aggregates | `ash_money` (already) |
| `localize_lua` 1.0 | `localize.*` table for Luerl scripts | `ash_lua`, and `ash_cms`, which it already names |
| `intl` 1.0 | `Intl`-shaped ergonomic API | `ash_typescript` parity |
| `localize_person_names`, `localize_phone_number`, `localize_address` 1.0 | Name, phone and postal-address formatting | the corresponding `ash_localize` types |

Two renames landed on 2026-07-31: `localize_ecto` is now **`localize_sql`** (and absorbed `localize_units_sql`), and `localize_phonenumber` is now **`localize_phone_number`**.

## Part I — What already exists

Implemented and on `main` in `ash_localize`, across three commits.

**CLDR-validated types.** `Locale`, `Territory`, `Subdivision` (with an optional `:territory` constraint), `Timezone`, `CurrencyCode` — each a plain `Ash.Type` storing a string, casting through Localize to CLDR canonical form (`"en-us"` → `"en-US"`, `"Australia/ACT"` → `"Australia/Sydney"`) and rejecting unknown subtags. Matching `AshLocalize.Validations.*` for applications that would rather keep a `:string` attribute and guard its contents.

**Units of measure as per-category types.** `Speed`, `Mass`, `Length`, `Temperature`, `Area`, `Volume`, `Force`, `Power`, `Voltage`, `Angle`, `Energy`, `Pressure`, `Frequency`, `Digital`, `ElectricCurrent`, `Acceleration`, over a shared engine, with a generic `:unit` escape hatch and `AshLocalize.UnitType` for defining new ones.

This design is better than the one Kip's earlier assessment proposed. That assessment suggested following `ash_money` — a composite `{value, unit}` column, with `localize_units_sql` supplying the storage. `ash_localize` instead makes the unit *type metadata*: the column holds a plain number in the category's base unit, writes accept any dimensionally-compatible unit and convert (`{7.8, "kilometer-per-second"}` stores `7800`), cross-category writes are rejected, and the loaded value is a `%Localize.Unit{}`. Because the column is numeric, `sum`, `avg`, sorting and filtering run natively on every data layer — which the composite approach forfeits. Alembic changed to this mid-implementation and recorded why.

**Composite domain types.** `PersonName` (name parts, rendered with culturally correct order and formality), `PhoneNumber` (parsed and validated via libphonenumber, stored E.164), `PostalAddress` (CLDR components, country-correct multi-line rendering). Each behind an optional dependency on the corresponding satellite package.

**Numeric semantic types.** `Count` (plural-aware via MF2, with an `:of` tag naming what is being counted), `Ordinal`, `Percentage`, `Ratio`, `Score`, `Rating`. These capture what a number *means* so it can be rendered correctly, and have no counterpart in Kip's earlier assessment.

**Formatting as calculations.** Fifteen `Format*` calculations — number, currency, date, datetime, list, unit, address, person name, phone, count, ordinal, percent, ratio, score, rating — reading the resolved locale from calculation context, so they are correct under async.

**Locale resolution.** `AshLocalize.Context.locale/2`, a four-arm chain, most specific first: explicit `:locale` argument → `:locale` in `Ash.Context` → actor-derived (opt-in) → application default. Absent a default it returns `{:error, :no_locale}` rather than a silent `nil`. The process dictionary is deliberately excluded.

**Packaging.** One package. `localize` is the only hard dependency; every satellite, plus `ash_postgres` and `ash_phoenix`, is `optional: true` behind a `Code.ensure_loaded?/1` guard. The application's dependency list is the feature switch. An Igniter installer writes the config and detects which satellites are present.

The remaining phases in `ash_localize`'s plan, in its order: Postgres optimisations (4), Phoenix bridge (5), GraphQL/JSON:API registrations (6), translations via an `Embedded` store (7), a `SiblingResource` store (8), and a `localize_translate` adapter (9).

## Part II — Corrections and answers

Two things `ash_localize` is working from have gone out of date, both cheap to fix.

**Package renames.** `PLAN.md` refers to `localize_units_sql` fand `localize_phonenumber`. Both were retired on 2026-07-31: `localize_units_sql` merged into **`localize_sql`**, which now owns the shared DDL machinery; `localize_phonenumber` became **`localize_phone_number`**, package, repo and directory.

**The ecosystem is 1.0.** Published 2026-07-31 and 2026-08-01: `localize`, `calendrical`, `intl`, `unity`, `localize_sql`, `localize_web`, `localize_address`, `localize_phone_number`, `localize_person_names` and `localize_lua` all at 1.0.0; `localize_translate` at 0.2.0, held pre-1.0 pending agreement on the store behaviour; the input components at 0.2.0; `localize_mcp` at 0.2.0; `ex_money` 6.2.0 and `ex_money_sql` 2.1.0 rebuilt on it. This removes the largest risk Kip's earlier assessment recorded — that Ash would not take a dependency on a release candidate — and the version-alignment prerequisite it listed is done.

### Answers to the five open questions

Kip proposes the following answers to the questions raised in `ash_localize`'s `PLAN.md`.

1. **`localize_translate` interface shape.** It is behaviour-shaped, not Ecto-coupled — see *The store behaviour* below.

2. **MF2 catalogue conventions.** `ash_localize.<context>.<key>` is consistent with how Localize's own Gettext-backed messages are namespaced. Worth settling before phase 7 rather than after.

3. **Composite-type stability in PostgreSQL.** Settled. `localize_sql` 1.0.0 ships composite types with database-side aggregates (`sum`, `min`, `max`, `avg`) and arithmetic operators, generated from one shared spec; `ex_money_sql` 2.1.0 is built on that same machinery. Native composites are viable for `PhoneNumber` and `PersonName` — though `ash_localize`'s own reasoning about numeric columns and native aggregates applies here too, so JSONB may still be the better default for types nobody aggregates.

4. **Elixir-side collator.** `Localize.Collation.compare/2` and `Localize.Collation.sort/2` are stable public API in 1.0, implementing the CLDR root collation with locale tailorings. `:unicode_util` is not a substitute; it gives codepoint order, not linguistic order.

    The premise of the question no longer holds for SQLite, though. `localize_sql` ships **`localize_icu`**, a SQLite loadable extension registering ICU collations under the same names PostgreSQL uses, plus `Localize.Ecto.SQLite3` in place of `Localize.Ecto`. The same locale resolves to the same collation name and produces the same ordering on either database — the test suite asserts that parity across a range of languages and tailorings. SQLite therefore gets collation *in the data layer*, not a best-effort Elixir sort. The runtime collator is the fallback only for data layers with no SQL at all: ETS, Mnesia.

5. **The unpublished translation work.** There is no separate successor. `localize_translate` is the translation store, now carrying the behaviour below. It stays a package in its own right rather than merging into `localize_sql` — the two share a dependency shape but not a purpose, and an application choosing the `LocalizeTranslate` store should not have to pull in collation, composite types and unit Ecto types to get JSONB translations.

    It is deliberately held at **0.2.0 rather than 1.0** until the callback shape is agreed. The behaviour is new public API whose first real consumer is `ash_localize`, so fixing it at 1.0 before an adapter exists would turn any requested change into a major bump. 1.0 follows agreement on the shape.

### The store behaviour

`localize_translate` 0.2 ships `Localize.Translate.Store`, a storage behaviour that is deliberately not Ecto-coupled:

```elixir
@callback fetch_translation(subject, locale, field, options) :: {:ok, term()} | :error
@callback put_translation(subject, locale, field, value, options) :: {:ok, subject} | {:error, term()}
@callback load_translations(subject, options) :: {:ok, subject} | {:error, term()}
@callback locales(subject, options) :: [locale]
@callback queryable?() :: boolean()
```

`put_translation/5` and `load_translations/2` are optional. A read-only store — one backed by a translation service — need not implement the first; a store whose translations already travel with the subject need not implement the second. `Localize.Translate.Store.Embedded` is the default implementation over the existing container-map storage, so the behaviour is additive rather than a migration for anyone already using the package.

Three design points matter for the adapter.

Querying is a **declared capability** rather than a required callback. `queryable?/0` reports whether a store can push a predicate into the data layer, because filtering by translated text inside SQL has no meaning for an ETS or in-memory store. That is what lets a non-database store implement the behaviour honestly instead of raising on a callback it cannot satisfy.

`load_translations/2` exists because the first sibling-row implementation proved the contract needed it. Without a bulk load, a store keeping translations elsewhere issues one query per field per candidate locale — a two-field schema over a three-locale fallback chain costs six. With it, the store populates the container once and resolution reads from memory.

The callbacks are **subject-and-field shaped** rather than key-based. A store receives the whole subject, not an extracted key, so it can resolve without a second read, and a CLDR parent-chain fallback costs one pass.

That last point is the one open mismatch: `ash_localize`'s draft proposed `get_translation(key, locale, opts)`. The key-based shape is the more general of the two; the subject-and-field shape carries enough information to evaluate a fallback chain. Adapting key-based onto subject-and-field is mechanical, but it is cheaper to settle before either side has an adapter.

## Part III — What only Ash can fix

Everything in Part I was built without a single change to Ash. That constraint is why it shipped, and why four gaps remain that no extension can close.

### 1. There is no display callback on `Ash.Type`

`Ash.Type` declares callbacks for `cast_input`, `cast_stored`, `dump_to_native`, `dump_to_embedded`, `cast_from_embedded`, `apply_constraints`, `cast_atomic`, `handle_change`, `prepare_change`, `load`, `rewrite`, `generator` and more — and `describe/1`, which documents the *type*, not a value. Nothing renders a value for a human.

The consequences are visible downstream and are not fixed by `ash_localize` existing. `ash_admin` reduces every attribute to `to_string/1` (`lib/ash_admin.ex:48`, `lib/ash_admin/components/resource/show.ex:605`), so a `:decimal` price renders `1234.5` in every locale on earth. `ash_phoenix` contains no reference to gettext or translation anywhere in `lib`.

`ash_localize`'s `Format*` calculations are the right workaround and are genuinely useful — a resource can declare `calculate :price_display, ...` where display is wanted. But a calculation is opt-in per field per resource, and `ash_admin` renders attributes it has never been told about; it cannot call a calculation the resource author did not declare. Proposed:

```elixir
@callback to_display(term(), constraints(), opts :: Keyword.t()) ::
            {:ok, String.t()} | {:error, term()}
```

Optional, defaulting to `{:ok, to_string(value)}`, so nothing breaks. `ash_localize` then supplies implementations for its own types and for the builtins, and `ash_admin`, `AshPhoenix` and `ash_typescript` get one call site instead of three hand-rolled ones. The signature deliberately mirrors `Localize.Chars.to_string/2`, which is already `{:ok, binary} | {:error, exception}` over precisely the set of types Ash treats as builtins.

`AshMoney.Types.Money` is the worked example for why this belongs in core. It accepts formatting options in *type constraints*:

```elixir
attribute :charge, :money do
  constraints: [ex_money_opts: [no_fraction_if_integer: true, format: :short]]
end
```

Display configuration in constraints is a reasonable response to there being nowhere else to put it, but it binds presentation to the schema: the same attribute cannot render `:short` in a summary table and long-form on a detail page. A display callback taking runtime options fixes that, and constraints become defaults rather than the format.

### 2. Input parsing is locale-blind

`cast_input/2` for `:integer`, `:float`, `:decimal`, `:date` and `:datetime` delegates to `Ecto.Type.cast/2`. A German user typing `1.234,5` into a form bound to a `:decimal` gets a cast error, because Ecto reads `.` as the decimal separator. A user typing `10/07/2025` gets whatever the ISO-8601 parser makes of it, with no reference to whether their locale is day-first or month-first.

Localization is usually treated as an output concern. It is at least as much an input concern, and getting it wrong produces validation errors users cannot act on — the field looks correct to them.

Both halves are solved outside Ash:

```elixir
iex> Calendrical.parse("10/07/2025", locale: :"en-GB")
{:ok, ~D[2025-07-10]}

iex> Calendrical.parse("10/07/2025", locale: :"en-US")
{:ok, ~D[2025-10-07]}

iex> Localize.Number.Parser.parse("1.234,5", locale: :de)
{:ok, 1234.5}
```

That pair is the clearest case for the Ash core team: same input, same type, two locales, two different correct dates, and no way for Ash to express the difference today. `Calendrical.parse/2` also takes `as: :map` to return the unresolved partial (`%{month: 5, day: 5}` for `"May 5"`), which is what a form library needs to distinguish "user omitted the year" from "user meant this year".

Proposed: `cast_display/3`, the input mirror of `to_display/3`, tried before `cast_input/2` when a locale is present in context.

This is the half `ash_localize` cannot reach at all. Its types validate and canonicalize their *own* values, but a `:decimal` attribute is Ash's type, and a form posting to it never passes through `ash_localize`.

### 3. Async work silently loses the locale

`Ash.ProcessHelpers.get_context_for_transfer/1` transfers only tracer span context — that is the entire body of the function. Localize stores the current locale in the process dictionary (`Process.put(:localize_locale, tag)`, `lib/localize.ex:367`), as does ex_cldr, as does Gettext.

So any value formatted inside an async calculation, a parallel relationship load, or anything routed through `Ash.ProcessHelpers.task_with_timeout/5` formats in the application default locale, not the request locale. The same applies to `ash_oban` jobs and Reactor steps. This is a live latent bug for `ash_money` today.

`ash_localize` has already done its half correctly — resolution reads context, never the process dictionary, and its `Format*` calculations take the locale from calculation context. That protects `ash_localize`'s own output. It does not protect *user* code inside async work, where `Localize.get_locale/0` still returns the default. Carrying the locale in `get_context_for_transfer/1` is a few lines and fixes a class of bug that stays invisible until someone reports their invoice PDF is in English.

### 4. Sorting is not linguistic

`Ash.Sort` supports `:asc`, `:desc` and the four nils variants. There is no collation concept, and `Ash.Sort.runtime_sort/3`'s own documentation treats the problem as unfixable:

> Keep in mind that it is unrealistic to expect this runtime sort to always be exactly the same as a sort that may have been applied by your data layer. This is especially true for strings.

It is fixable, and the important half is in the data layer rather than at runtime. `localize_sql` resolves a language tag to the best-matching ICU collation via CLDR language matching and emits `COLLATE` inside an ordinary Ecto query:

```elixir
from p in Product, order_by: collate(p.name, "sv")
from p in Product, where: collate(p.name < "münchen", "de")
from p in Product, order_by: collate(p.name, collation: "german_phonebook")
```

Unknown locales degrade gracefully (`"zh-TW"` → `zh-Hant-x-icu`), and BCP 47 collation types such as `de-u-co-phonebk` resolve to collations created once in a migration.

This matters more than the runtime fix because a runtime sort can only reorder the page already fetched — the wrong answer whenever the sort determines *which* rows are on the page, which is every paginated list. So the primary integration is the data layer emitting `COLLATE`: `ash_postgres` natively, and `ash_sqlite` through the `localize_icu` extension, which registers the same collation names so a query sorts identically on either. `Localize.Collation.sort/2` is the fallback only where there is no SQL to push into.

`ash_localize`'s planned Postgres phase already includes collation fragments, so that half is in hand. What needs Ash is `:locale` on `Ash.Sort.runtime_sort/3`, routing string comparison through a pluggable collator, so the two paths agree.

### A fifth, smaller one

`Ash.Type.Enum.label/1` resolves against a compile-time map, so `label: gettext("Open")` silently freezes the default locale at compile time. Reported in [ash#2172](https://github.com/ash-project/ash/issues/2172), with a maintainer noting multiple people hit it. The fix landed as a documented two-pass workaround written by hand per enum. A locale-aware arity would remove the boilerplate. Ergonomics rather than a missing capability — worth raising alongside the others, not on its own.

## Part IV — The error-message pipeline, and why it is the opening move

Ash's mechanism is a marker macro plus a mix task. `Ash.Gettext.error_message/1` returns its argument unchanged at runtime and exists so `mix ash.gettext.extract` can scan for it; messages land in `priv/gettext/ash.pot`, applications copy that file with `mix ash.gen.gettext`, and render via `Gettext.dgettext(MyApp.Gettext, "ash", msg, vars)`.

The workflow is sound. The message format is not, and the defects are structural rather than oversights.

**No plural selection, in any locale.** Gettext selects a plural form from a variable named `count`. There are zero occurrences of `count` in Ash's shipped `priv/gettext/ash.pot`. Ash's counted messages name their variable after the constraint instead: `"at least %{at_least} of %{keys} must be present"` (`lib/ash/resource/validation/present.ex:185`), `"must have no more than %{precision} significant digits"`, `"Expected %{expected_length} elements, got %{value_length}"`. `ash_admin` implements the correct branch — `if count = opts[:count], do: Gettext.dngettext(...), else: Gettext.dgettext(...)` (`lib/ash_admin/components/core_components.ex:646`) — but it is dead code for Ash errors, because the count is never called `count`. Every Ash error message renders through singular-only `dgettext`, and Russian, Polish and Arabic get one form where they need three, three and six.

**Interpolated values are not formatted.** `%{max}` is substituted with `to_string(value)`. Ash's own `decimal.ex` and `float.ex` pass raw numbers into `"must be less than or equal to %{max}"`, so a `de-DE` user reads `1234.5` where they expect `1.234,5`.

**Lists are joined with a hard-coded English comma.** `lib/ash/type/atom.ex:60` and `lib/ash/resource/validation/present.ex:186` both call `Enum.join(list, ", ")`, and the value is baked into the interpolation variable before the translator sees it — so no `.po` file can correct it.

MessageFormat 2 addresses all three in one move. Taking Ash's own message verbatim, with both branches holding the same untranslated English, isolates what MF2 fixes *before* a translator touches anything:

```elixir
iex> Localize.Message.format(msg, %{"at_least" => 3, "keys" => ["name", "email", "phone"]}, locale: :en)
{:ok, "at least 3 of name, email, and phone must be present"}

iex> Localize.Message.format(msg, %{"at_least" => 3, "keys" => ["name", "email", "phone"]}, locale: :de)
{:ok, "at least 3 of name, email und phone must be present"}

iex> Localize.Message.format(msg, %{"at_least" => 1234, "keys" => ["name", "email", "phone"]}, locale: :de)
{:ok, "at least 1.234 of name, email und phone must be present"}
```

The list gains a locale-correct conjunction and the number locale-correct grouping, without a word being translated. Neither is reachable from a `.po` file at any level of translator effort, because `Enum.join/2` has already run. Plural selection then works on any named variable:

```elixir
iex> for n <- [1, 3, 5, 21], do: Localize.Message.format(ru_msg, %{"at_least" => n}, locale: :ru)
[{:ok, "нужно указать минимум 1 поле"},     # one
 {:ok, "нужно указать минимум 3 поля"},     # few
 {:ok, "нужно указать минимум 5 полей"},    # many
 {:ok, "нужно указать минимум 21 поле"}]    # one — 21 takes the singular in Russian
```

This is the opening move with the Ash core team, for four reasons. It needs no change to Ash. It demonstrates in a screenshot. It answers a request already accepted in principle — [ash#1771](https://github.com/ash-project/ash/issues/1771), which asked for translatable error messages and got the extraction half. And it is the one item here that provably cannot be built the current way, so it competes with nothing else on their roadmap.

Deliverable: `AshLocalize.translate_error/1`, matching the shape `AshPhoenix.Form` expects, rendering Ash's existing msgids through `Localize.Message.format/3`, with MF2 translations shipped for a first tranche of locales. One config line for the application; no change to Ash; no change to application code.

The full migration of Ash's shipped messages from `%{var}` to MF2 is a separate, later, opt-in-per-domain conversation. The msgid conversion is mechanical, but it changes the translator workflow, so it should lag everything else.

## Part V — Calendars, and the rest of the ecosystem

The capability with no competing answer anywhere in Elixir, and the one that most clearly distinguishes Ash.

`calendrical` 1.0 implements 17 CLDR-aligned calendar systems — Persian, Hebrew, four Islamic variants, Japanese imperial eras, Buddhist, ROC (Minguo), Indian National, Ethiopic, Coptic, Chinese, Korean Dangi — with `Date.shift/2` arithmetic working across all of them, plus fiscal-year calendars for around 50 territories.

For Ash: a `:date` attribute whose *storage* stays an ISO `Date` while its display and input follow the user's calendar. An application serving Thailand, Japan, Saudi Arabia, Iran or Israel currently builds that itself. `localize_datetime_inputs` already renders multi-calendar date pickers against `calendrical`, so the client half exists; `ash_localize`'s planned `<.ash_input>` dispatcher is where it lands.

This depends on Part III item 2 — without `cast_display/3`, a non-Gregorian date typed by a user has nowhere to be parsed.

The fiscal-year support is a quieter commercial angle: reporting resources where "Q3" must mean the right three months in the right territory.

Two smaller items belong here. `localize_lua` exposes a curated, sandboxed `localize.*` table to Luerl scripts — relevant to `ash_lua`, and it already names `ash_cms` as a consumer. And `intl` provides an `Intl`-shaped API that gives `ash_typescript` a way to keep client and server formatting consistent, since both ends then speak the same option names.

Money is not on this list, because it is done. `ex_money` 6.2 is Localize-backed and `ash_money` already resolves Localize transitively. The remaining work there is a `mix deps.unlock --unused` to clear a dead `ex_cldr_currencies` entry from `ash_money`'s committed lock file.

## Part VI — Sequencing

One roadmap across both projects. **[A]** is `ash_localize`, Alembic's to build; **[L]** is Localize-side, Kip's; **[U]** needs a change to Ash core and a conversation with its maintainers.

**Now — no dependencies, no coordination**

1. **[A]** Correct the package renames in `PLAN.md` and `README.md`: `localize_units_sql` → `localize_sql`, `localize_phonenumber` → `localize_phone_number`. Move dependency requirements to the 1.0 line.
2. **[L]** Build `AshLocalize.translate_error/1` and the MF2 translations for Ash's shipped `.pot`, contributed to `ash_localize` rather than shipped as a competing package.
3. **[A + L]** Settle the store callback shape — `Localize.Translate.Store` is subject-and-field shaped, the `ash_localize` draft was key-based. `localize_translate` stays at 0.2.x until this lands, then goes 1.0.

**Next — `ash_localize`'s remaining phases, unblocked**

4. **[A]** Postgres optimisations, now that `localize_sql` 1.0 provides the composite machinery and the collation resolution.
5. **[A]** Phoenix bridge: `LocalePlug`, the `<.ash_input>` dispatcher, multi-locale form handling.
6. **[A]** GraphQL / JSON:API registrations.
7. **[A]** Translations: `Embedded`, then `SiblingResource`, then the `LocalizeTranslate` adapter — all three against one contract now that the behaviour exists.

**Then — upstream in Ash if the proposal is accepted**

8. **[U]** `to_display/3` on `Ash.Type`. Highest leverage, smallest diff.
9. **[U]** `cast_display/3`. Unblocks locale-aware input and, with it, non-Gregorian date entry.
10. **[U]** Locale in `get_context_for_transfer/1`.
11. **[U]** `:locale` on `Ash.Sort.runtime_sort/3`, paired with item 4's `COLLATE` path.
12. **[U]** Locale-aware arity on `Ash.Type.Enum.label/1`.

**Later — the differentiators**

13. **[A]** Multi-calendar attributes, once item 9 exists.
14. **[A]** Fiscal-year reporting.
15. **[L]** `ash_lua` / `ash_cms` via `localize_lua`; `ash_typescript` parity via `intl`.
16. **[U]** MF2 for Ash's own messages. Opt-in per domain, last, and only once item 2 has proven itself.

The ordering has one property worth stating: nothing before item 8 requires the Ash core team to accept anything. By the time the upstream conversation happens there is a working package, a visible fix to a problem they have already acknowledged, and users.

## A possible first step

The error-message translator, framed as a follow-up to [ash#1771](https://github.com/ash-project/ash/issues/1771) rather than as a new proposal — that issue asked for translatable error messages and got the extraction half; the rendering half is still singular-only.

Three things to pair with it:

* The `mix deps.unlock --unused` observation on `ash_money`. Localize is already in the Ash dependency tree; a dead ex_cldr entry proves how long that has been true.
* `allenwyma`'s comment on #1771 — "I've just been overwriting some and including my own Gettext inside. Probably not good cause now we have the web mixed with the domains." A user independently deriving the argument for putting locale on `Ash.Scope` rather than reaching for a web-layer Gettext backend inside domain code.
* That `Ash.Scope`'s canonical documentation example is already `defstruct [:current_user, :current_tenant, :locale]`, and `Ash.Query`'s docs already illustrate `put_context(:locale, "en_US")`. The plumbing and the idiom exist; nothing in Ash reads them. Standardising the key is closer to a documentation change than a code change.

Together those make the point without asking for anything: Ash already ships Localize, its users have asked for this twice, the integration already exists, and here is the piece that cannot be built the current way.

## Risks

* **Ownership.** `ash_localize` is Alembic's. This plan contributes to it rather than forking or paralleling it. Localize-side work that duplicates it is waste, and worse, it splits the story when it reaches the Ash core team.
* **Ash guards its core.** A 54-callback behaviour is already a lot; adding two more, even optional ones, needs a clear argument that they belong in core rather than an extension. The argument is that display is not optional in a framework shipping an admin UI, a form library and three serializers — it is currently just implicit and inconsistent.
* **Breadth reads as sprawl.** Fifteen packages is a lot of surface for a framework team to evaluate. Lead with one problem and one fix; `ash_localize`'s single-package-with-optional-dependencies layout is the right answer and should be described that way.
* **Serialization boundaries must hold.** The likeliest way this goes wrong is a well-meaning PR making `ash_json_api` emit localized numbers. State the principle in the guides, loudly, before the code lands.
* **MySQL has no collation story.** PostgreSQL and SQLite both do — the latter through the `localize_icu` extension `localize_sql` ships — so `ash_postgres` and `ash_sqlite` can both push `COLLATE` into the query. `ash_mysql` falls back to the runtime collator, which cannot fix a paginated sort. `ash_localize`'s data-layer matrix currently records SQLite as "best-effort, Elixir-side", which is now out of date.
* **The store behaviour is new public API with no Ash adapter written against it yet.** Mitigated rather than eliminated: `localize_translate` stays on 0.x until the shape is agreed, so a requested change costs a minor bump instead of a major one. The mitigation holds only while it stays pre-1.0.

## What is genuinely missing

* **Agreement on the store callback shape.** Item 3 in the sequencing. It is the only thing gating `localize_translate` 1.0 and `ash_localize` phase 7.
* **No date/time parsing in Localize core.** It lives in `calendrical`, which is the right place, but the input story needs a second dependency rather than falling out of `localize` alone.
* **Process-dictionary locale.** Correct and conventional for Elixir, but every framework that spawns processes must opt in to carrying it. A constraint to respect explicitly rather than a defect — and item 10 is how Ash respects it.
