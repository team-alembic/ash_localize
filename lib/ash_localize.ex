defmodule AshLocalize do
  @moduledoc """
  Ash Framework integration for [Localize](https://github.com/elixir-localize/localize),
  the CLDR-backed localization library for Elixir.

  `ash_localize` makes Ash resources locale-aware at the resource level: CLDR-validated
  typed attributes, locale-aware formatting calculations, translatable string fields, and
  a single deterministic locale-resolution chain.

  See the [README](readme.html) for an overview and the project roadmap.
  """

  @doc """
  Returns the application default locale.

  Read from `config :ash_localize, default_locale: ...`. This is the final arm of the
  `AshLocalize.Context.locale/2` resolution chain. Returns `nil` when unconfigured —
  resolution then reports `{:error, :no_locale}` rather than silently producing `nil`.
  """
  @spec default_locale() :: String.t() | nil
  def default_locale do
    Application.get_env(:ash_localize, :default_locale)
  end
end
