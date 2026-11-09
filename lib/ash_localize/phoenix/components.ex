if Code.ensure_loaded?(Phoenix.Component) do
  defmodule AshLocalize.Phoenix.Components do
    @moduledoc """
    Phoenix function components for the `:locale`, `:timezone` and `:person_name` types.

    Each component takes a `Phoenix.HTML.FormField` and renders labels from CLDR data
    through Localize. Import the module into your `html_helpers` to use them:

        import AshLocalize.Phoenix.Components

    Compiled only when `phoenix_live_view` is a dependency of your application.
    """

    use Phoenix.Component

    alias AshLocalize.Types.Locale
    alias Localize.DateTime.Timezone, as: LocalizeTimezone
    alias Localize.Locale.LocaleDisplay
    alias Localize.PersonName.Formatter, as: NameFormatter

    @surname_parts [:surname_prefix, :surname, :other_surnames]
    @given_parts [:given_name, :other_given_names, :informal_given_name]

    @autocomplete %{
      title: "honorific-prefix",
      given_name: "given-name",
      other_given_names: "additional-name",
      informal_given_name: "nickname",
      surname: "family-name",
      generation: "honorific-suffix",
      credentials: "honorific-suffix"
    }

    @doc """
    Renders a `<select>` of locales, each labelled with its own name in its own language.

    An option reads like "🇩🇪 Deutsch (Deutschland)": the territory's flag, when the
    locale names a territory, then the locale's autonym. The option matching the
    field's canonicalised value is selected. Set `prompt` to add a first option with
    the value `""`, which `:locale` attributes cast to `nil`.
    """
    attr :field, Phoenix.HTML.FormField, required: true

    attr :locales, :list,
      default: nil,
      doc: "locale ids; defaults to Localize's supported locales"

    attr :prompt, :string, default: nil, doc: "label of a first option with the value \"\""
    attr :class, :string, default: nil
    attr :rest, :global, include: ~w(autocomplete disabled form required)

    def locale_select(assigns) do
      assigns =
        assigns
        |> assign(:options, locale_options(assigns.locales))
        |> assign(:selected, canonical_locale(assigns.field.value))

      ~H"""
      <select id={@field.id} name={@field.name} class={@class} {@rest}>
        <option :if={@prompt} value="">{@prompt}</option>
        <option
          :for={{value, label, dir} <- @options}
          value={value}
          lang={value}
          dir={dir}
          selected={value == @selected}
        >
          {label}
        </option>
      </select>
      """
    end

    @doc """
    Renders a text input with a `<datalist>` of IANA time zones.

    Each option's value is the canonical IANA id and its label is built from CLDR in
    `locale`, such as "London · British Time (GMT+01:00)". The offset is today's
    offset and appears only when Elixir has a time zone database configured. Option
    lists are cached per locale and recomputed once a day.
    """
    attr :field, Phoenix.HTML.FormField, required: true

    attr :zones, :list,
      default: nil,
      doc: "IANA ids; defaults to every canonical zone `:timezone` stores"

    attr :locale, :any, default: nil, doc: "display locale; defaults to `Localize.get_locale/0`"
    attr :placeholder, :string, default: nil
    attr :class, :string, default: nil
    attr :rest, :global, include: ~w(autocomplete disabled form readonly required)

    def timezone_input(assigns) do
      assigns =
        assigns
        |> assign(:options, timezone_options(assigns.zones, assigns.locale))
        |> assign(:list_id, "#{assigns.field.id}_zones")

      ~H"""
      <input
        type="text"
        id={@field.id}
        name={@field.name}
        value={Phoenix.HTML.Form.normalize_value("text", @field.value)}
        list={@list_id}
        placeholder={@placeholder}
        autocomplete="off"
        spellcheck="false"
        class={@class}
        {@rest}
      />
      <datalist id={@list_id}>
        <option :for={{zone, label} <- @options} value={zone}>{label}</option>
      </datalist>
      """
    end

    @doc """
    Returns the human label `timezone_input/1` shows for an IANA time zone.

    Use it to display a stored `:timezone` value, for example "Wien ·
    Mitteleuropäische Zeit (Österreich) (GMT+01:00)" in `"de"`.
    """
    @spec timezone_label(String.t(), Localize.LanguageTag.t() | String.t() | atom() | nil) ::
            String.t()
    def timezone_label(iana_id, locale \\ nil) do
      build_timezone_label(iana_id, display_locale(locale), now_in_zones())
    end

    @doc """
    Renders one labelled text input per name part of a `:person_name` field.

    Each input is named `field[part]`, so the form submits a map that
    `AshLocalize.Types.PersonName` casts. Parts follow the locale's name order:
    surname first for locales such as `"ja"` and `"zh"`. Labels are passed in already
    translated, so the host application keeps the wording in its own Gettext catalogue.
    """
    attr :field, Phoenix.HTML.FormField, required: true
    attr :parts, :list, default: [:given_name, :surname]

    attr :labels, :map,
      required: true,
      doc: "translated label for each part, such as `%{given_name: gettext(\"Given name\")}`"

    attr :locale, :any,
      default: nil,
      doc: "decides the part order; defaults to the current locale"

    attr :class, :string, default: nil, doc: "class of the wrapping element"
    attr :part_class, :string, default: nil, doc: "class of each part's wrapper"
    attr :label_class, :string, default: nil
    attr :input_class, :string, default: nil
    attr :rest, :global

    def person_name_input(assigns) do
      locale = display_locale(assigns.locale)

      assigns =
        assign(assigns, :ordered_parts, order_name_parts(assigns.parts, name_order(locale)))

      ~H"""
      <div class={@class} {@rest}>
        <div :for={part <- @ordered_parts} class={@part_class}>
          <label for={"#{@field.id}_#{part}"} class={@label_class}>{Map.fetch!(@labels, part)}</label>
          <input
            type="text"
            id={"#{@field.id}_#{part}"}
            name={"#{@field.name}[#{part}]"}
            value={name_part(@field.value, part)}
            autocomplete={Map.get(autocomplete_hints(), part)}
            class={@input_class}
          />
        </div>
      </div>
      """
    end

    defp autocomplete_hints, do: @autocomplete

    defp locale_options(nil), do: locale_options(Localize.supported_locales())

    defp locale_options(locales) do
      Enum.flat_map(locales, fn locale ->
        with value when is_binary(value) <- canonical_locale(locale),
             {:ok, tag} <- Localize.validate_locale(value),
             {:ok, name} <- LocaleDisplay.display_name(tag, locale: tag) do
          [{value, with_flag(value, name), AshLocalize.Phoenix.text_direction(tag)}]
        else
          _unknown_or_root -> []
        end
      end)
    end

    # A validated tag carries likely subtags, so "ja" would gain JP; the flag comes
    # from the territory the locale id names itself.
    defp with_flag(locale_id, name) do
      with {:ok, %Localize.LanguageTag{territory: territory}} when not is_nil(territory) <-
             Localize.LanguageTag.parse(locale_id),
           {:ok, flag} when flag != "" <- Localize.Territory.unicode_flag(territory) do
        flag <> " " <> name
      else
        _no_territory -> name
      end
    end

    defp canonical_locale(%Localize.LanguageTag{} = tag),
      do: canonical_locale(Localize.LanguageTag.to_string(tag))

    defp canonical_locale(locale) when locale in [:und, "und", :root, "root"], do: nil

    defp canonical_locale(locale) do
      case Locale.cast_input(locale, []) do
        {:ok, canonical} -> canonical
        _invalid -> nil
      end
    end

    defp display_locale(nil), do: Localize.get_locale().cldr_locale_id

    defp display_locale(locale) do
      case Localize.validate_locale(locale) do
        {:ok, tag} -> tag.cldr_locale_id
        {:error, _reason} -> display_locale(nil)
      end
    end

    defp timezone_options(zones, locale) do
      locale = display_locale(locale)
      {default_options, labels} = cached_timezone_labels(locale)

      case zones do
        nil ->
          default_options

        zones ->
          now = now_in_zones()

          Enum.map(zones, fn zone ->
            {zone, Map.get_lazy(labels, zone, fn -> build_timezone_label(zone, locale, now) end)}
          end)
      end
    end

    # The labels carry today's GMT offset, so the cache is keyed by date as well as
    # locale; a daily rebuild picks up daylight-saving changes.
    defp cached_timezone_labels(locale) do
      key = {__MODULE__, :timezone_labels, locale}
      today = Date.utc_today()

      case :persistent_term.get(key, nil) do
        {^today, options, labels} ->
          {options, labels}

        _stale_or_missing ->
          now = now_in_zones()

          options =
            Enum.map(LocalizeTimezone.known_timezones(), fn zone ->
              {zone, build_timezone_label(zone, locale, now)}
            end)

          labels = Map.new(options)
          :persistent_term.put(key, {today, options, labels})
          {options, labels}
      end
    end

    defp now_in_zones do
      utc_now = DateTime.utc_now()

      fn zone ->
        case DateTime.shift_zone(utc_now, zone) do
          {:ok, datetime} -> datetime
          {:error, _no_database} -> nil
        end
      end
    end

    defp build_timezone_label(zone, locale, now) do
      datetime = now.(zone)
      zone_info = datetime || %{time_zone: zone, utc_offset: 0, std_offset: 0}

      names =
        [exemplar_city(zone, locale), generic_zone_name(zone_info, zone, locale)]
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      label = Enum.join(names, " · ")

      # A fixed-offset zone such as Etc/GMT+5 is named by its offset already.
      case datetime && LocalizeTimezone.gmt_format(datetime, locale) do
        {:ok, offset} -> if offset in names, do: label, else: "#{label} (#{offset})"
        _no_offset -> label
      end
    end

    defp exemplar_city(zone, locale) do
      case LocalizeTimezone.exemplar_city(zone, locale) do
        {:ok, city} -> city
        {:error, _reason} -> nil
      end
    end

    # Without a datetime the offset is unknown, and a GMT fallback would print a
    # wrong one, so only a named zone counts.
    defp generic_zone_name(%DateTime{} = datetime, _zone, locale) do
      case LocalizeTimezone.non_location_format(datetime, locale, type: :generic) do
        {:ok, name} -> name
        {:error, _reason} -> nil
      end
    end

    defp generic_zone_name(_zone_info, zone, locale) do
      case LocalizeTimezone.generic_location_format(zone, locale) do
        {:ok, name} -> name
        :error -> nil
      end
    end

    defp name_part(nil, _part), do: nil

    defp name_part(value, part) when is_map(value) do
      case Map.get(value, part) do
        nil -> Map.get(value, Atom.to_string(part))
        found -> found
      end
    end

    defp name_part(_value, _part), do: nil

    defp order_name_parts(parts, :surname_first) do
      {surname, rest} = Enum.split_with(parts, &(&1 in @surname_parts))

      case Enum.find_index(rest, &(&1 in @given_parts)) do
        nil -> parts
        index -> rest |> List.insert_at(index, surname) |> List.flatten()
      end
    end

    defp order_name_parts(parts, _given_first), do: parts

    if Code.ensure_loaded?(Localize.PersonName.Formatter) do
      # localize_person_names resolves CLDR's nameOrderLocales through the locale's
      # parent chain; an empty name leaves the locale as the only input.
      defp name_order(locale) do
        with {:ok, tag} <- Localize.validate_locale(locale),
             {:ok, options} <-
               NameFormatter.determine_name_order(
                 %Localize.PersonName{},
                 tag,
                 []
               ) do
          Keyword.get(options, :order, :given_first)
        else
          _unknown -> :given_first
        end
      end
    else
      defp name_order(_locale), do: :given_first
    end
  end
end
