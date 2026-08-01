# MessageFormat 2 translations for Ash's shipped error messages — Russian.
#
# SEED, pending translator review. Russian is here first because it is the clearest
# demonstration of what Gettext cannot do for Ash: three plural forms selected from a
# variable named `at_least` rather than `count`, which Gettext's plural machinery
# cannot see. An msgid absent from this file is not an error — it falls back to the
# English string with locale-correct interpolated values.
#
# Keys are Ash msgids exactly as they appear in Ash's priv/gettext/ash.pot.

%{
  "at least %{at_least} of %{keys} must be present" => """
  .input {$at_least :number}
  .match $at_least
  one  {{нужно указать минимум {$at_least} поле}}
  few  {{нужно указать минимум {$at_least} поля}}
  many {{нужно указать минимум {$at_least} полей}}
  *    {{нужно указать минимум {$at_least} поля}}
  """
}
