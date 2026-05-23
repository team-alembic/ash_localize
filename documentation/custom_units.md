# Custom units

`ash_localize` ships 16 per-category unit types (`Speed`, `Mass`, `Length`, …) plus a
generic `:unit` escape hatch. Between CLDR's unit grammar and Localize's custom
registry, almost any quantity is reachable. This guide shows the three patterns, from
zero-setup to fully custom.

## 1. Compound units — no setup needed

CLDR composes unit identifiers from primitives with `-per-`, `square-`, `cubic-`, and
so on. *Jerk* — the rate of change of acceleration — is `meter-per-cubic-second`.
Localize parses and converts such compounds out of the box.

The generic `:unit` type handles it directly:

```elixir
attribute :jerk, :unit, constraints: [base_unit: "meter-per-cubic-second"]
```

Casting accepts any dimensionally-compatible unit — `{1, "foot-per-cubic-second"}`
converts to metres per cubic second on the way in — and stores a plain number.
Incompatible units (a mass into a jerk attribute) are rejected.

One caveat: display patterns for very-uncommon compounds may render as the raw
identifier (`"9 meter-per-cubic-second"`) rather than a localised phrase. That is a
CLDR data gap, not a library limit.

## 2. A reusable custom dimensioned type

For developer ergonomics, define your own type so resources can write
`attribute :j, :jerk` instead of repeating the constraint on every attribute:

```elixir
defmodule MyApp.Units.Jerk do
  use AshLocalize.UnitType, base_unit: "meter-per-cubic-second"
end
```

Register the short name and use it as you would any built-in type:

```elixir
# config/config.exs
config :ash, :custom_types,
  jerk: MyApp.Units.Jerk

# in any resource
attribute :spacecraft_jerk, :jerk
attribute :imperial_jerk, :jerk, constraints: [base_unit: "foot-per-cubic-second"]
```

`AshLocalize.UnitType` is the same machinery the 16 built-ins (`Speed`, `Mass`,
`Length`, …) are generated from. Pass `category:` to restrict to a CLDR category
(`"speed"`, `"length"`, `"force"`, …) for the strongest guard — it distinguishes
same-dimension categories such as frequency vs. radioactivity. Omit it for a type
defined purely by its `base_unit`, as in the jerk example; dimensional compatibility
is still enforced through Localize's conversion.

For more than one custom unit, `defunit/2` reduces the ceremony to one line each:

```elixir
import AshLocalize.UnitType

defunit MyApp.Units.Jerk, base_unit: "meter-per-cubic-second"
defunit MyApp.Units.RadialAcceleration, base_unit: "meter-per-square-second"
defunit MyApp.Units.SpecificImpulse, base_unit: "meter-per-second"
```

## 3. Genuinely custom *named* units

If a unit is not expressible as a CLDR compound — a domain-specific unit with its own
name and conversion factors, like a *smoot* — register it once with Localize, and the
whole `ash_localize` machinery accepts it:

```elixir
Localize.Unit.CustomRegistry.register("smoot", %{
  # definition: base_unit, conversion factor, display name, …
})

attribute :bridge_length, :unit, constraints: [base_unit: "smoot"]
```

See `Localize.Unit.CustomRegistry` for the definition shape and `register_batch/1` /
`load_file/1` for bulk loads.

## Picking between the three

| You want… | Use |
| --- | --- |
| A one-off attribute with a CLDR-composable unit | `:unit` with explicit `base_unit:` (pattern 1) |
| A reusable named type across the codebase | a module that `use`s `AshLocalize.UnitType` (pattern 2) |
| A unit CLDR does not know — your own name and conversions | `Localize.Unit.CustomRegistry.register/2` (pattern 3) |

The three compose: register a custom name with `CustomRegistry`, then build a reusable
type around it with `AshLocalize.UnitType`.
