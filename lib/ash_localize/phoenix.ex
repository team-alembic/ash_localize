defmodule AshLocalize.Phoenix do
  @moduledoc """
  Locale helpers for Phoenix templates that need no Phoenix dependency.

  The form inputs live in `AshLocalize.Phoenix.Components`, which compiles only when
  `phoenix_live_view` is present.
  """

  @doc """
  Returns the text direction of a locale, `"rtl"` or `"ltr"`, for an HTML `dir` attribute.

  The answer comes from the locale's CLDR character order, so `"ar"` and `"he"` are
  `"rtl"`. A locale that cannot be resolved is `"ltr"`.

      iex> AshLocalize.Phoenix.text_direction("en")
      "ltr"
  """
  @spec text_direction(Localize.LanguageTag.t() | String.t() | atom()) :: String.t()
  def text_direction(locale) do
    with {:ok, tag} <- Localize.validate_locale(locale),
         {:ok, %{character_order: :rtl}} <- Localize.Locale.get(tag.cldr_locale_id, [:layout]) do
      "rtl"
    else
      _ltr_or_unknown -> "ltr"
    end
  end
end
