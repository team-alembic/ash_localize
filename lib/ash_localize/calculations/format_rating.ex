defmodule AshLocalize.Calculations.FormatRating do
  @moduledoc """
  An Ash calculation that renders a rating as `"X / Y"` (e.g. `"4.5 / 5"`), or as a
  plural-aware sentence (`"4.5 stars out of 5"`) when a template is supplied.

      # default — "X / Y"
      calculate :rating_display, :string,
        {AshLocalize.Calculations.FormatRating, field: :rating, out_of: 5}

      # plural-aware via MF2
      calculate :rating_display, :string,
        {AshLocalize.Calculations.FormatRating,
         field: :rating,
         out_of: 5,
         one: "{$rating} star out of {$out_of}",
         other: "{$rating} stars out of {$out_of}"}

  ## Options

    * `:field` (required) — the numeric attribute (typically `AshLocalize.Types.Rating`).
    * `:out_of` (required) — the maximum of the scale; passed as the `$out_of` MF2
      binding and used in the default `"X / Y"` rendering.
    * `:template` — a raw MF2 message string.
    * `:if_zero`, `:zero`, `:one`, `:two`, `:few`, `:many`, `:other` — short forms
      assembled into an MF2 template (the variable is `$rating`).
    * `:actor_locale` — an actor-locale extractor, as for `AshLocalize.Context.locale/2`.

  A `nil` source value produces a `nil` result.
  """

  use Ash.Resource.Calculation

  alias AshLocalize.Calculations.Helpers

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
         :ok <- ensure_out_of(opts),
         {:ok, template} <- build_template(opts) do
      {:ok, Keyword.put(opts, :template_string, template)}
    end
  end

  @impl true
  def load(_query, opts, _context), do: [opts[:field]]

  @impl true
  def calculate(records, opts, context) do
    template = opts[:template_string]
    out_of = opts[:out_of]

    Helpers.format(records, opts, context, fn rating, locale, _record ->
      render(template, rating, out_of, locale)
    end)
  end

  defp ensure_out_of(opts) do
    case opts[:out_of] do
      n when is_number(n) -> :ok
      _ -> {:error, "FormatRating requires an `:out_of` option (a number)"}
    end
  end

  defp build_template(opts) do
    cond do
      raw = opts[:template] -> {:ok, raw}
      has_any_plural_form?(opts) -> {:ok, assemble_template(opts)}
      true -> {:ok, :default_fraction}
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

    ".input {$rating :number}\n.match $rating\n" <> cases
  end

  defp render(:default_fraction, rating, out_of, locale) do
    rating_str = number(rating, locale)
    out_of_str = number(out_of, locale)
    "#{rating_str} / #{out_of_str}"
  end

  defp render(template, rating, out_of, locale) when is_binary(template) do
    bindings = %{"rating" => to_mf2_number(rating), "out_of" => to_mf2_number(out_of)}

    case Localize.Message.format(template, bindings, locale: locale) do
      {:ok, formatted} -> formatted
      {:error, reason} -> raise "AshLocalize could not format rating: #{inspect(reason)}"
    end
  end

  # MF2's plural selector needs a plain Elixir number to apply CLDR plural rules
  # correctly — pass a `Decimal` and an integer-equivalent like `Decimal.new(1)` is
  # resolved as `other` rather than `one`. Coerce to an integer when whole,
  # otherwise to a float.
  defp to_mf2_number(%Decimal{} = d) do
    rounded = Decimal.round(d, 0)
    if Decimal.equal?(d, rounded), do: Decimal.to_integer(rounded), else: Decimal.to_float(d)
  end

  defp to_mf2_number(n), do: n

  defp number(value, locale) do
    case Localize.Number.to_string(value, locale: locale) do
      {:ok, formatted} -> formatted
      {:error, reason} -> raise "AshLocalize could not format number: #{inspect(reason)}"
    end
  end
end
