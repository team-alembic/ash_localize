defmodule AshLocalize.Calculations.FormatCount do
  @moduledoc """
  An Ash calculation that renders an integer count as a locale- and plural-aware
  string via MessageFormat 2.

  Works with any integer attribute — including `AshLocalize.Types.Count` and Ash
  aggregates returning an integer.

      calculate :comment_count_display, :string,
        {AshLocalize.Calculations.FormatCount,
         field: :comment_count,
         if_zero: "No comments",
         one: "1 comment",
         other: "{$count} comments"}

  ## Options

    * `:field` (required) — the integer attribute or aggregate to render.
    * `:template` — a raw MF2 message string. Use this when the plural-form
      options below are not enough (the variable name is `$count`).
    * `:if_zero`, `:zero`, `:one`, `:two`, `:few`, `:many`, `:other` — short forms
      that this calculation assembles into an MF2 template at compile time.
      `:if_zero` matches the literal value `0`; the others are CLDR plural categories.
      At least `:one` and `:other` (or `:template`) must be supplied.
    * `:actor_locale` — an actor-locale extractor, as for `AshLocalize.Context.locale/2`.

  ## Locale-specific plural forms

  Japanese has a single plural category. A locale-specific catalogue (Phase 7) will
  resolve `of:` to the right template per locale — including Japanese counter words.
  Until then, supply locale-specific templates via `:template`, or use the
  English-shaped defaults and override in your view layer.

  A `nil` source value produces a `nil` result.
  """

  use Ash.Resource.Calculation

  alias AshLocalize.Calculations.Helpers

  # Order matters for the assembled template — more specific selectors first.
  @selectors [
    if_zero: "0",
    zero: "zero",
    one: "one",
    two: "two",
    few: "few",
    many: "many",
    other: "*"
  ]

  @impl true
  def init(opts) do
    with {:ok, opts} <- Helpers.require_field(opts),
         {:ok, template} <- build_template(opts) do
      {:ok, Keyword.put(opts, :template_string, template)}
    end
  end

  @impl true
  def load(_query, opts, _context), do: [opts[:field]]

  @impl true
  def calculate(records, opts, context) do
    template = opts[:template_string]

    Helpers.format(records, opts, context, fn count, locale, _record ->
      Localize.Message.format!(template, %{"count" => count}, locale: locale)
    end)
  end

  defp build_template(opts) do
    cond do
      raw = opts[:template] ->
        {:ok, raw}

      has_any_plural_form?(opts) ->
        {:ok, assemble_template(opts)}

      true ->
        {:error,
         "FormatCount requires either `:template` or plural forms (e.g. `:one`, `:other`)"}
    end
  end

  defp has_any_plural_form?(opts) do
    Enum.any?(@selectors, fn {key, _} -> Keyword.has_key?(opts, key) end)
  end

  defp assemble_template(opts) do
    cases =
      @selectors
      |> Enum.flat_map(fn {key, selector} ->
        case opts[key] do
          nil -> []
          value -> ["#{selector} {{#{value}}}"]
        end
      end)
      |> Enum.join("\n")

    ".input {$count :integer}\n.match $count\n" <> cases
  end
end
