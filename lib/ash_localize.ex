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

  @doc """
  Formats a value to a locale-aware string by dispatching on its type.

  The library's stance is that values carry their dimension — `%Money{}` knows its
  currency, `%Localize.Unit{}` knows its base unit, `%Date{}` is structurally
  identifiable — so formatting only needs the value itself, not the resource and an
  attribute name. This is the function you reach for in Phoenix templates, LiveView,
  scripts, and any code where you already have the value in hand:

      AshLocalize.format(order.price)         # "$1,234.50"
      AshLocalize.format(order.delta_v)       # "7,800 m/s"
      AshLocalize.format(order.starts_on)     # "May 22, 2026"
      AshLocalize.format(order.tags)          # "apples, oranges, and pears"

  `nil` passes through. Built-in support covers `Integer`, `Float`, `Decimal`,
  `Date`, `NaiveDateTime`, `DateTime`, `List`, and `Localize.Unit`. Optional support
  for `Money`, `Localize.PhoneNumber.Number`, `Localize.Address.Address`, and
  `Localize.PersonName` is compiled in when the matching dependency is present.

  Extend to a custom type by implementing the `AshLocalize.Format` protocol.

  ## Options

    * `:locale` — explicit locale; the highest-precedence arm of the resolution chain.
      When absent, falls back to the application default via `AshLocalize.Context`.
    * Format-specific keys are passed through to the upstream renderer — e.g.
      `format: :national` for a phone number, `usage: :referring` for a person name.

  Raises `Protocol.UndefinedError` for a value with no registered formatter; the
  message names the type so you know what to implement.
  """
  @spec format(term(), keyword()) :: String.t() | nil
  def format(value, opts \\ [])
  def format(nil, _opts), do: nil
  def format(value, opts) when is_list(opts), do: AshLocalize.Format.format(value, opts)
end
