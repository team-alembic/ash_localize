# Response to the integrated plan update

Reply to `ASH_LOCALIZE_PLAN_UPDATE.md`. 2026-08-02.

Short version: all five answers accepted, item 1 is done, item 2 is built. Two
small asks on the store behaviour, one gap neither document covers, and one
point of disagreement at the end.

## Item 1 is done

`localize` 0.37 → 1.0, `localize_person_names` 0.1 → 1.0, `localize_address`
0.2 → 1.0. **Zero source changes** — all 288 tests passed unmodified. Worth
citing when the Ash team asks how stable the dependency is.

`localize_phone_number` is off its git reference and onto Hex 1.0. Renames
corrected everywhere, readiness table updated with real versions.

**Gotcha for the 1.0 migration notes:** `ex_money` 6.0 requires
`localize ~> 0.27`, which forbids 1.0 outright. The resolver blames the lock
rather than `ex_money`:

```
Because "the lock" depends on "ex_money 6.0.0" which depends on "localize ~> 0.27",
"the lock" requires "localize ~> 0.27".
```

6.2.0 fixes it. Anyone on 6.0/6.1 hits this and the error does not say why.

Two corrections to Part V:

- `ash_money` no longer needs a git pin. 0.2.6 on Hex requires `ex_money ~> 6.0`
  and resolves against 6.2 and Decimal 3. It is a plain Hex dependency now.
- The `deps.unlock --unused` / dead `ex_cldr_currencies` point cannot be
  confirmed from here. Hex packages ship no lockfile, so it concerns the GitHub
  repository rather than anything a consumer sees. Probably still true — worth
  checking before it leads the pitch.

## Something the update predates

`AshLocalize.format/1,2` already exists, built on `Localize.Chars`:

```elixir
AshLocalize.format(Decimal.new("1234.5"))      #=> "1,234.5"
AshLocalize.format(Money.new(:USD, "1234.5"))  #=> "$1,234.50"
AshLocalize.format(~D[2026-05-22])             #=> "May 22, 2026"
```

That is the proposed `to_display/3` signature, already working. It turns Part III
item 1 from "here is a callback we would like" into "here is the implementation,
please give it a home".

One caveat before citing it: `format/2` resolves locale via
`Context.locale!(%{}, argument: opts[:locale])` — an empty context. It honours an
explicit `:locale` and falls back to the application default, and never consults
Ash context or the actor. Fine for templates and exporters, but it is not the
four-arm chain, so it should not be described as locale-resolution-complete.

Also shipped since: a `Localize.Chars` implementation for `%Money{}` (the one
value type in Ash that the protocol did not already cover), and `usage-rules.md`.

## The five answers

All accepted. Two changes requested on Q1 before `localize_translate` goes 1.0:

- **`queryable?/0` should take an argument.** The same store module can be
  queryable over Postgres and not over ETS. `queryable?(subject)` or
  `queryable?(opts)`. Cheap now, breaking later.
- **`fetch_translation/4` returning bare `:error`** leaves nowhere for "the
  translation service was unreachable" to go. A network-backed read-only store is
  exactly the case `queryable?` exists to accommodate, so the error channel
  probably deserves the same treatment.

Otherwise subject-and-field is right and the key-based draft was wrong — the
one-pass parent-chain argument settles it. `ash_localize`'s behaviour will match
`Localize.Translate.Store` rather than adapting between two contracts.

Q3: agreed. Applying the numeric-column reasoning, the deciding question becomes
"does anyone aggregate this?" Nobody sums phone numbers, so JSONB by default and
native composites opt-in.

Q4 is the most useful item in the update. The data-layer matrix currently records
SQLite locale-aware sort as "best-effort, Elixir-side", which is now wrong in the
pessimistic direction. Being corrected. **Where is the `localize_icu` parity test
suite?** "Sorts identically on either database" is a strong claim and is better
cited than asserted.

## Item 2 — taken, and built

The update marks `translate_error/1` as Localize-side work. Taken instead: it
lives in `ash_localize`, its first consumer is `ash_localize`, and it is what the
Ash team would be shown. Localize-side effort is better spent on the other half
of Q4 and on getting the store behaviour to 1.0, both of which block this side
and neither of which this side can do.

`AshLocalize.translate_error/1,2` is on `main`. Two commits, 27 tests.

The Part IV examples all check out, verified against the actual shipped `.pot`
first. The numbers are worth having in the pitch: **zero of Ash's 58 msgids
contain `%{count}`**, so Gettext's plural selection can never fire on any of
them, and the English join is at `present.ex:186`.

```
ru, plural selected from `at_least`, not `count`:
  1  → нужно указать минимум 1 поле     (one)
  3  → нужно указать минимум 3 поля     (few)
  5  → нужно указать минимум 5 полей    (many)
  21 → нужно указать минимум 21 поле    (one)

untranslated de, nothing in the catalogue at all:
  "at least 1 of a und b must be present"
```

The second one is the demo: correct conjunction, no translation involved, and
unreachable from a `.po` file at any level of translator effort.

Two design notes:

- The catalogue is a behaviour (`config :ash_localize, error_catalogue:`), with
  the builtin reading `priv/messages/ash/<locale>.exs` at compile time and
  falling back down subtags so `ru-RU` inherits `ru`. Interim format — happy to
  move to whatever catalogue convention lands.
- Exactly **one** translated message ships, marked as a seed pending review.
  Inventing plural forms for languages nobody on this side speaks is not
  something to put in a package. A real first tranche needs a reviewer.

**One caveat for the pitch.** Ash pre-joins list variables, so from real
validations `%{keys}` is already the string `"a, b, c"` and the conjunction fix
does *not* apply — only the number formatting does. Those are passed through
untouched rather than split on `", "`, because a value can legitimately contain a
comma. So the list case should be demoed with a message that passes a real list,
and the limitation stated up front. Better said than noticed in the room.

## The gap neither document covers: locale data

The most important thing to resolve, because it affects the error-message tranche
directly.

`localize` ships `:en` only. Everything else is a CDN fetch,
`allow_runtime_locale_download` defaults to `false`, and a miss falls back to
`:und` **silently**:

```
[debug] Requested locale :de is not available. Trying parent locales.
[debug] Loaded and using locale :und (parent locale of :de).
de: {:ok, "at least 3 of name, email, phone must be present"}
```

No conjunction, English grouping, and still `{:ok, ...}`. Defensible for a
formatting call where the developer sees the log. Not defensible for error
messages, where the whole argument over Gettext is that the German user gets
German plurals — a deployment that forgot `mix localize.download_locales` gets
neither, silently, and finds out through a support ticket.

This surfaced because the test suite here only ever asserted `en` output. It
never claimed otherwise, so nothing was failing, but a localization library with
no multi-locale coverage is testing the plumbing rather than the point. Now
configured with eight locales and the download wired into the `test` alias
(~5MB, fetched rather than committed).

Three questions:

1. **Should the installer configure this?** Inclined to have
   `mix igniter.install ash_localize` set `otp_app:` and prompt for
   `supported_locales` — an Ash application is a deployed application, and the
   `otp_app` form is the one that survives releases. That is a policy decision
   about Localize's configuration, so better agreed than assumed.
2. **Is there a strict mode?** Something like `on_missing_locale: :error` so the
   silent `und` fallback becomes `{:error, ...}`. For error messages, CI should
   fail loudly rather than ship English plurals to Russian users.
3. **What is the CI convention?** Commit the cache, fetch at build, or fixtures?
   Better to follow an existing convention than invent a third.

## The point of disagreement

The Risks section names "breadth reads as sprawl" and the document is then
fifteen packages wide. That risk is underweighted rather than mitigated.

Part VI's sequencing is right, and its stated property is the valuable part:
nothing before item 8 requires the Ash core team to accept anything. Going
further — the first conversation should mention **one** package and **one**
problem, the singular-only error pipeline, with `localize` as an implementation
detail of the fix rather than an ecosystem to evaluate. Calendars, the Lua bridge
and `intl` parity are all genuinely differentiating, and all of them are reasons
for a framework team to defer a decision rather than make one.

Item 2 ships, demonstrates in a screenshot, and fixes something already
acknowledged in ash#1771. That is the whole opening move. The rest is the second
conversation.

## Not covered here

The upstream Ash proposals — Part III items 8–12 and the Part IV msgid migration
— are being written up separately, so those arguments are deliberately left alone
rather than duplicated. The one thing that document should pick up is the
`AshLocalize.format/1,2` precedent above.

## Questions, collected

1. `queryable?/0` → `queryable?/1` before 1.0?
2. Does `fetch_translation/4` want an error channel separate from not-found?
3. Where is the `localize_icu` collation parity suite?
4. Should the installer configure `otp_app` / `supported_locales`?
5. Strict mode for missing locale data — exists, or worth adding?
6. CI convention for locale data in a library test suite?
