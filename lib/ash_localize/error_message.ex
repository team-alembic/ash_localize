defmodule AshLocalize.ErrorMessage do
  @moduledoc """
  Renders Ash error messages with locale-correct interpolated values.

  Ash marks its error messages for extraction with `Ash.Gettext.error_message/1` and
  ships them in `priv/gettext/ash.pot`. The extraction half of that pipeline works.
  The rendering half has three defects that no `.po` file can repair, because they
  happen to the *values* rather than to the words:

    * **Interpolated numbers are not formatted.** `%{max}` is substituted with
      `to_string(value)`, so a `de` user reads `1234.5` where they expect `1.234,5`.
      Ash's own `decimal.ex` and `float.ex` pass raw numbers into
      `"must be less than or equal to %{max}"`.

    * **Lists are joined with an English comma.** `%{keys}` and friends arrive
      pre-joined — see `Enum.join(opts[:attributes], ", ")` in Ash's
      `validation/present.ex` — so the conjunction is baked in before a translator
      ever sees the string.

    * **There is no plural selection, in any locale.** Gettext selects a plural form
      from a variable named `count`, and there are zero occurrences of `%{count}` in
      Ash's 58 shipped msgids — the counted messages name their variable after the
      constraint instead (`%{at_least}`, `%{precision}`, `%{expected_length}`). Every
      Ash error therefore renders through singular-only `dgettext`.

  This module addresses the first two, for every Ash message, with no translation
  work and no change to Ash: values are rendered through Localize before
  substitution, so numbers group correctly and real lists take the locale's
  conjunction. Plural selection needs a translated MessageFormat 2 catalogue and is
  handled separately.

  ## Usage

      AshLocalize.translate_error({"must have %{max} or fewer items", max: 1234},
        locale: "de")
      #=> "must have 1.234 or fewer items"

  Accepts the `{message, vars}` shape Phoenix's `translate_error/1` convention uses,
  a bare message string, or any Ash error struct carrying `:message` and `:vars`.

  ## The list caveat

  A list variable is only rendered with the locale's conjunction when it actually
  arrives as a list:

      iex> AshLocalize.translate_error({"%{keys} must be present", keys: ~w[a b c]}, locale: "de")
      "a, b und c must be present"

  Ash currently joins these before building the error, so from real Ash validations
  the value is already the string `"a, b, c"` and is passed through unchanged. We
  deliberately do not split it back apart — a value may legitimately contain a comma,
  and guessing would corrupt it. Recovering the conjunction for Ash's own messages
  needs the join removed upstream.
  """

  @doc """
  Renders `error` in the resolved locale.

  See the module documentation. Options are passed to `AshLocalize.Context.locale/2`,
  so `:locale` wins over the application default.
  """
  @spec translate(term(), keyword()) :: String.t()
  def translate(error, opts \\ [])

  def translate(message, opts) when is_binary(message), do: translate({message, []}, opts)

  def translate({message, vars}, opts) when is_binary(message) do
    locale = AshLocalize.Context.locale!(%{}, argument: opts[:locale])

    vars
    |> normalize_vars()
    |> Enum.reduce(message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", render(value, locale))
    end)
  end

  def translate(%{message: message, vars: vars}, opts) when is_binary(message) do
    translate({message, vars}, opts)
  end

  def translate(%{message: message}, opts) when is_binary(message) do
    translate({message, []}, opts)
  end

  defp normalize_vars(nil), do: []
  defp normalize_vars(vars) when is_map(vars), do: Map.to_list(vars)
  defp normalize_vars(vars) when is_list(vars), do: vars

  # A list is the one shape worth routing through Localize's list formatter — it is
  # the case a `.po` file provably cannot reach. Everything else goes through
  # `Localize.Chars`, which already covers the numeric types Ash interpolates and
  # falls back to `to_string/1` for the rest.
  defp render(value, locale) when is_list(value) do
    case Localize.List.to_string(value, locale: locale) do
      {:ok, formatted} -> formatted
      {:error, _reason} -> Enum.map_join(value, ", ", &to_string/1)
    end
  end

  defp render(value, locale) do
    case Localize.Chars.to_string(value, locale: locale) do
      {:ok, formatted} -> formatted
      {:error, _reason} -> to_string(value)
    end
  end
end
