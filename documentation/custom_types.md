# Adding a type

`ash_localize` groups its types by what the value *is*. Three kinds, three macros.
Picking the right one is most of the work; each macro then supplies everything
except the part that genuinely differs.

| Kind | The value is | Storage | Macro | Examples |
|---|---|---|---|---|
| **Code** | a member of a controlled vocabulary | string | `AshLocalize.CodeType` | `:locale`, `:territory`, `:timezone`, `:currency_code`, `:subdivision` |
| **Quantity** | a dimensionless magnitude with meaning | number | `AshLocalize.QuantityType` | `:count`, `:ordinal`, `:percentage`, `:ratio`, `:score`, `:rating` |
| **Unit** | a dimensioned magnitude | number, in a base unit | `AshLocalize.UnitType` | `:length`, `:mass`, `:speed`, and 13 more |

The distinction that matters is **nominal versus quantitative**. A code cannot be
ordered or aggregated — comparing two is equality, not magnitude. `"AUD" < "BRL"`
is alphabetical trivia, not a fact about currencies. A quantity can be summed,
averaged and sorted, and the only question left is whether it carries a dimension.

If you find yourself wanting to add a bound to a code, or a vocabulary to a
quantity, you have probably picked the wrong kind.

## Generating one

```bash
mix ash_localize.gen.type MyApp.Types.Script --kind code \
  --validator Localize.validate_script --short-name script

mix ash_localize.gen.type MyApp.Types.Probability --kind quantity \
  --min 0.0 --max 1.0 --short-name probability

mix ash_localize.gen.unit_type MyApp.Units.Jerk \
  --base-unit meter-per-cubic-second --short-name jerk
```

## Codes

A code type stores a string, rejects anything outside the vocabulary, and
canonicalises what it accepts. Only the validation differs, so that is all you
write:

```elixir
defmodule MyApp.Types.Script do
  use AshLocalize.CodeType, message: "is not a valid script"

  @impl true
  def cast_code(value, _constraints) do
    case Localize.validate_script(value) do
      {:ok, code} -> {:ok, to_string(code)}
      {:error, _reason} -> code_error()
    end
  end
end
```

`cast_code/2` receives a binary — `nil`, atoms and non-string input are handled
before it is called — and returns `{:ok, canonical}` or `{:error, keyword}`.
`code_error/0` produces the message you declared.

Return a keyword list directly when the reason is more useful than "invalid".
`AshLocalize.Types.Subdivision` does this to report the territory a code failed
against:

```elixir
{:error, message: "is not a subdivision of %{territory}", territory: "AU"}
```

Codes are often written as atoms, so `:AUD` and `"AUD"` are both accepted. Storage
is always a string.

Take `:constraints` if the vocabulary needs narrowing — again, Subdivision, whose
`:territory` constraint restricts valid codes to one country.

## Quantities

Usually a declaration and nothing else:

```elixir
defmodule MyApp.Types.Probability do
  use AshLocalize.QuantityType,
    storage: :decimal,
    message: "is not a number",
    min: 0.0,
    max: 1.0
end
```

Storage is `:integer` or `:decimal`, and stays a plain number so `sum`, `avg`,
sorting and filtering run natively on every data layer.

Two options exist for bounds that are named for a domain rather than a mechanism.
`AshLocalize.Types.Rating` has an upper bound of `:out_of`, not `:max`:

```elixir
use AshLocalize.QuantityType,
  storage: :decimal,
  message: "is not a number",
  min: 0.0,
  max_key: :out_of,
  max_required?: true
```

which makes the constraint `out_of: 5` and the error read *must be at most
%{out_of}*.

For checks bounds cannot express, override `extra_errors/2`. It returns a list,
concatenated with any bound errors, so a value failing two rules reports both:

```elixir
@impl true
def extra_errors(0, constraints) do
  if Keyword.get(constraints, :zero?, true), do: [], else: [[message: "must not be zero"]]
end

def extra_errors(_value, _constraints), do: []
```

That is `AshLocalize.Types.Count`'s `:zero?`, and currently the only use of the
callback in the library.

## Units

Units have their own guide — see [Custom units](custom_units.md) — because a
dimensioned quantity needs a base unit and, optionally, a CLDR category, and
neither generalises to the other kinds. The short version:

```elixir
defmodule MyApp.Units.Jerk do
  use AshLocalize.UnitType, base_unit: "meter-per-cubic-second"
end
```

## Registering the short name

Any type is usable by module, but a short name reads better in a resource:

```elixir
config :ash, :custom_types, script: MyApp.Types.Script
```

```elixir
attribute :writing_system, :script
```

`mix ash_localize.gen.type --short-name script` writes that config for you.
