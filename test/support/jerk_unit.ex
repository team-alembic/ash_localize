defmodule AshLocalize.Test.Jerk do
  @moduledoc false
  # A category-less custom unit type used by `AshLocalize.UnitTypeTest`. *Jerk* (the
  # rate of change of acceleration) is `meter-per-cubic-second` — a CLDR compound
  # with no CLDR category, the canonical case for using `AshLocalize.UnitType`
  # without a `:category`.

  use AshLocalize.UnitType, base_unit: "meter-per-cubic-second"
end
