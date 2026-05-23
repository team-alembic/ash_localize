# Defines `AshLocalize.Test.JerkShortcut` via the `defunit/2` one-liner, to exercise
# the macro shortcut alongside the long-form `AshLocalize.Test.Jerk`.

import AshLocalize.UnitType

defunit(AshLocalize.Test.JerkShortcut, base_unit: "meter-per-cubic-second")
