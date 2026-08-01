defmodule AshLocalize.ErrorMessage.Catalogue do
  @moduledoc """
  Source of MessageFormat 2 translations for Ash error messages.

  A catalogue maps an Ash msgid — the English string as it appears in Ash's shipped
  `priv/gettext/ash.pot` — to an MF2 message for a locale. `AshLocalize.ErrorMessage`
  consults one before falling back to interpolating the English msgid.

  MF2 rather than Gettext because the defect being fixed is plural selection, and
  Gettext selects a plural form only from a variable named `count`. Ash's counted
  messages name their variable after the constraint (`%{at_least}`, `%{precision}`),
  so Gettext's plural machinery can never fire on them. MF2 selects on any named
  variable:

      .input {$at_least :number}
      .match $at_least
      one  {{нужно указать минимум {$at_least} поле}}
      few  {{нужно указать минимум {$at_least} поля}}
      many {{нужно указать минимум {$at_least} полей}}
      *    {{нужно указать минимум {$at_least} поля}}

  ## Configuring

      config :ash_localize, error_catalogue: MyApp.Catalogue

  Defaults to `AshLocalize.ErrorMessage.Catalogue.Builtin`, which reads the `.exs`
  files under `priv/messages/ash/` at compile time.
  """

  @doc """
  Fetches the MF2 message for `msgid` in `locale`, or `:error` when untranslated.

  Returning `:error` is the ordinary case, not a failure — an untranslated message
  falls back to the English msgid with locale-correct interpolated values, which is
  already better than what Ash renders today.
  """
  @callback fetch(msgid :: String.t(), locale :: String.t()) :: {:ok, String.t()} | :error

  @doc false
  @spec impl() :: module()
  def impl do
    Application.get_env(:ash_localize, :error_catalogue, __MODULE__.Builtin)
  end
end
