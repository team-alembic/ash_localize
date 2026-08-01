# AshLocalize usage rules

Rules for LLM coding agents using `ash_localize` as a dependency. These are not
exhaustive — see the HexDocs guides for full reference.

## Core stance: values carry their dimension

The library's whole proposition is that a value should carry its own
dimensional information — currency for money, base unit for `:speed`, IANA
name for `:timezone`, full BCP 47 tag for `:locale`, the noun being counted
for `:count`. A bare number with its unit hidden in a sibling column (or, far
worse, in a comment) is the anti-pattern this library is built to retire.

Apply this stance at every modelling decision. The defaults below are not
preferences; they are how this library believes the domain should be shaped.

## Money

**Always model monetary values with [`AshMoney.Types.Money`](https://hexdocs.pm/ash_money).**
Do not split money into a `:decimal` amount and a sibling `:currency_code`
column.

```elixir
# Right — amount and currency are one value.
attribute :price, AshMoney.Types.Money, public?: true

# Wrong — invites currency/amount drift, breaks multi-currency aggregates,
# loses arithmetic safety.
attribute :amount,   :decimal,       public?: true
attribute :currency, :currency_code, public?: true
```

`AshMoney.Types.Money` wraps [`ex_money`](https://hexdocs.pm/ex_money). The
loaded value is a `%Money{}` struct carrying both `amount` (Decimal) and
`currency` (atom like `:USD`). `AshLocalize.format/1` natively unpacks it:

```elixir
AshLocalize.format(order.price)   # "$1,234.50" or "¥1,500" — currency from value
```

`ash_money` is declared as an optional dependency on `ash_localize`. Add it to
your application's deps whenever you have money attributes. Without it,
`%Money{}` formatting is not compiled — everything else (other types,
formatting calculations, locale resolution) still works.

### Migrating legacy two-attribute money

A two-attribute shape (`:decimal` amount + `:currency_code` sibling) is
acceptable only as a migration ramp on a pre-existing schema;
`AshLocalize.Calculations.FormatCurrency` still supports
`currency_field: :some_attr` for that case, but new attributes go straight to
`Money`.

## Quantities (length, mass, speed, temperature, …)

Use a per-category unit type (`:speed`, `:length`, `:mass`, `:temperature`,
`:area`, `:volume`, `:force`, `:energy`, `:power`, `:pressure`, `:angle`,
`:frequency`, `:digital`, `:electric_current`, `:voltage`,
`:acceleration`) — not a bare `:decimal` plus a `:unit` column.

```elixir
# Right — base unit baked into type metadata; writes convert; loaded value
# is a %Localize.Unit{} that knows its unit.
attribute :delta_v, :speed, public?: true

# Wrong — separates the number from its dimension.
attribute :delta_v_value, :decimal, public?: true
attribute :delta_v_unit,  :string,  public?: true
```

For dimensions outside the built-in set, define your own with
`AshLocalize.UnitType`. See the [Custom units guide](documentation/custom_units.md).

## Counts

A "count of something" is a `:count`, not an `:integer`. The `:of` constraint
names the noun, drives plural-aware rendering, and is the key the translation
catalogue resolves for locale-specific templates (Japanese counter words,
etc.).

```elixir
# Right — semantic is in the type
attribute :comment_count, :count, constraints: [of: :comments], public?: true

# Wrong — a bare integer
attribute :comment_count, :integer, public?: true
```

Similar rules:

* Ranks → `:ordinal`, not `:integer`.
* Percentages (0–1) → `:percentage`, not `:decimal`.
* User-facing scores → `:score` (with `:min` / `:max`).
* Ratings → `:rating` with required `:out_of` and optional `:of`
  (`out_of: 5, of: :stars`).

## Locale, territory, timezone, currency, language, script

These are CLDR-validated string types — store them as the dedicated Ash type,
not as a bare `:string`:

| Concept | Type | Storage |
|---|---|---|
| BCP 47 locale | `:locale` | canonical string (`"en-US"`) |
| ISO 3166 country | `:territory` | upper-cased string (`"AU"`) |
| ISO 3166-2 subdivision | `:subdivision` | lower-cased string (`"caon"`) |
| IANA timezone | `:timezone` | canonical IANA name (`"Australia/Sydney"`) |
| ISO 4217 currency | `:currency_code` | upper-cased string (`"AUD"`) |

Each casts and validates against CLDR via Localize. Reach for the
`AshLocalize.Validations.Valid*` validations only when an existing `:string`
attribute can't be changed.

## Person names, phone numbers, postal addresses

Use the structured types from the optional satellite packages — never store a
person's name in a single `:string` column or a phone number as bare digits.

```elixir
attribute :author_name,     :person_name      # needs :localize_person_names
attribute :contact_phone,   :phone_number     # needs :localize_phone_number
attribute :shipping_address, :postal_address  # needs :localize_address
```

Each loads as a richer struct (`%Localize.PersonName{}`,
`%Localize.PhoneNumber.Number{}`, `%Localize.Address.Address{}`) that
`AshLocalize.format/1` can render locale-correctly.

## Formatting

`AshLocalize.format/1` is the primary entry point for rendering. It dispatches
on the value's type via the upstream `Localize.Chars` protocol. Use it in
Phoenix templates, LiveView, exporters, notification builders — anywhere you
already have the value in hand.

```eex
<%= AshLocalize.format(@order.price) %>
<%= AshLocalize.format(@order.starts_on) %>
<%= AshLocalize.format(@order.tags) %>
```

For API consumers (AshGraphQL, AshJsonApi, AshAdmin) that need a *field*
rather than a function call, define a formatting calculation
(`AshLocalize.Calculations.Format*`) that wraps the same dispatch. Same
source of truth, two surfaces.

## Locale resolution

Locale is resolved through `AshLocalize.Context.locale/2` from one
deterministic chain:

1. Explicit `:locale` argument or option (always wins).
2. `:locale` key on `Ash.Context` (set per-request via plug or
   `Ash.set_context/2`).
3. Actor-derived (opt-in via `actor_locale:` option).
4. Application default: `config :ash_localize, default_locale: "en"`.

Set the application default once. Set per-request locale via plug into
`Ash.Context`, not into the process dictionary — the process-dict route is
deliberately excluded so the resolution chain stays predictable.

## Installation

`mix igniter.install ash_localize` configures the default locale, registers
the short type names (`:locale`, `:territory`, `:subdivision`, `:timezone`,
`:currency_code`, `:count`, `:ordinal`, `:percentage`, `:ratio`, `:score`,
`:rating`, and the 16 unit categories), and detects any optional satellites
already in the consumer's deps. Always prefer the installer over hand-rolling
config.

## Module map

| Task | Use |
|---|---|
| Format any supported value | `AshLocalize.format/1,2` |
| Application default locale | `AshLocalize.default_locale/0` |
| Resolve active locale (in Ash code) | `AshLocalize.Context.locale/2` |
| Resolve in a calculation | `AshLocalize.Context.from_calculation/2` |
| Define a custom dimensioned unit type | `AshLocalize.UnitType` / `defunit/2` |
| Generate a custom unit type | `mix ash_localize.gen.unit_type` |
| Register `ash_localize` in a project | `mix igniter.install ash_localize` |
