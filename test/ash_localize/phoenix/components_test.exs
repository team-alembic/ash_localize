defmodule AshLocalize.Phoenix.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias AshLocalize.Phoenix.Components
  alias Localize.DateTime.Timezone

  doctest AshLocalize.Phoenix

  defp field(params, name), do: to_form(params, as: :profile)[name]

  defp options(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("option")
    |> Enum.map(fn option ->
      {option |> LazyHTML.attribute("value") |> List.first(), LazyHTML.text(option),
       LazyHTML.attribute(option, "selected") != []}
    end)
  end

  describe "locale_select/1" do
    test "labels each locale with its autonym, preceded by a flag when it has a territory" do
      html =
        render_component(&Components.locale_select/1,
          field: field(%{}, :locale),
          locales: ["de-DE", "ar-SA", "ja"]
        )

      labels =
        html |> options() |> Enum.map(fn {_value, label, _selected} -> String.trim(label) end)

      assert labels == [
               "🇩🇪 Deutsch (Deutschland)",
               "🇸🇦 العربية (المملكة العربية السعودية)",
               "日本語"
             ]

      assert html =~ ~s(dir="rtl")
    end

    test "defaults to the supported locales and leaves out the root locale" do
      html = render_component(&Components.locale_select/1, field: field(%{}, :locale))
      values = html |> options() |> Enum.map(fn {value, _label, _selected} -> value end)

      assert "de" in values
      assert "zh-Hant" in values
      refute "und" in values
    end

    test "selects the option matching the canonicalised field value" do
      html =
        render_component(&Components.locale_select/1,
          field: field(%{"locale" => "de-de"}, :locale),
          locales: ["en-GB", "de-DE"]
        )

      assert [{"en-GB", _, false}, {"de-DE", _, true}] = options(html)
    end

    test "renders a prompt option with an empty value first" do
      html =
        render_component(&Components.locale_select/1,
          field: field(%{}, :locale),
          locales: ["fr"],
          prompt: "Use the default"
        )

      assert [{"", "Use the default", false}, {"fr", _, false}] = options(html)
    end

    test "names the select after the form field" do
      html = render_component(&Components.locale_select/1, field: field(%{}, :locale))
      assert html =~ ~s(name="profile[locale]")
      assert html =~ ~s(id="profile_locale")
    end
  end

  describe "timezone_input/1" do
    test "lists every canonical zone in a datalist tied to the input" do
      html =
        render_component(&Components.timezone_input/1,
          field: field(%{"timezone" => "Europe/London"}, :timezone),
          locale: "en"
        )

      values = html |> options() |> Enum.map(fn {value, _label, _selected} -> value end)

      assert values == Timezone.known_timezones()
      assert "Europe/London" in values
      refute "Australia/ACT" in values
      assert html =~ ~s(list="profile_timezone_zones")
      assert html =~ ~s(<datalist id="profile_timezone_zones">)
      assert html =~ ~s(value="Europe/London")
    end

    test "labels zones in the display locale" do
      html =
        render_component(&Components.timezone_input/1,
          field: field(%{}, :timezone),
          locale: "de",
          zones: ["Europe/Vienna"]
        )

      assert [{"Europe/Vienna", label, false}] = options(html)
      assert label =~ "Wien"
      assert label =~ "Mitteleuropäische Zeit"
    end
  end

  describe "timezone_label/2" do
    test "joins the exemplar city, the generic zone name and the current offset" do
      assert Components.timezone_label("Asia/Tokyo", "en") ==
               "Tokyo · Japan Time (GMT+09:00)"
    end

    test "uses the display locale" do
      assert Components.timezone_label("Asia/Tokyo", "de") =~ "Tokio"
    end
  end

  describe "person_name_input/1" do
    @labels %{given_name: "Given name", surname: "Surname"}

    defp input_names(html) do
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("input")
      |> Enum.map(&(&1 |> LazyHTML.attribute("name") |> List.first()))
    end

    test "puts the given name first for en" do
      html =
        render_component(&Components.person_name_input/1,
          field: field(%{}, :name),
          labels: @labels,
          locale: "en"
        )

      assert input_names(html) == ["profile[name][given_name]", "profile[name][surname]"]
    end

    test "puts the surname first for ja" do
      html =
        render_component(&Components.person_name_input/1,
          field: field(%{}, :name),
          labels: @labels,
          locale: "ja"
        )

      assert input_names(html) == ["profile[name][surname]", "profile[name][given_name]"]
    end

    test "keeps title and generation where the caller put them" do
      html =
        render_component(&Components.person_name_input/1,
          field: field(%{}, :name),
          parts: [:title, :given_name, :surname, :generation],
          labels: Map.merge(@labels, %{title: "Title", generation: "Generation"}),
          locale: "ja"
        )

      assert input_names(html) == [
               "profile[name][title]",
               "profile[name][surname]",
               "profile[name][given_name]",
               "profile[name][generation]"
             ]
    end

    test "fills each part from a PersonName struct" do
      {:ok, name} = Localize.PersonName.new(given_name: "Ada", surname: "Lovelace")

      html =
        render_component(&Components.person_name_input/1,
          field: %{field(%{}, :name) | value: name},
          labels: @labels
        )

      assert html =~ ~s(value="Ada")
      assert html =~ ~s(value="Lovelace")
      assert html =~ ~s(<label for="profile_name_given_name")
      assert html =~ ~s(autocomplete="family-name")
    end

    test "fills each part from submitted params" do
      html =
        render_component(&Components.person_name_input/1,
          field: field(%{"name" => %{"given_name" => "Grace", "surname" => ""}}, :name),
          labels: @labels
        )

      assert html =~ ~s(value="Grace")
    end
  end

  describe "AshLocalize.Phoenix.text_direction/1" do
    test "is rtl for Arabic and ltr for Latin and CJK locales" do
      assert AshLocalize.Phoenix.text_direction("ar") == "rtl"
      assert AshLocalize.Phoenix.text_direction("ar-SA") == "rtl"
      assert AshLocalize.Phoenix.text_direction("de") == "ltr"
      assert AshLocalize.Phoenix.text_direction("ja") == "ltr"
    end

    test "is ltr for a locale it cannot resolve" do
      assert AshLocalize.Phoenix.text_direction("not a locale") == "ltr"
    end
  end
end
