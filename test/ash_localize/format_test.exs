defmodule AshLocalize.FormatTest do
  use ExUnit.Case, async: true

  # The locales asserted below are the ones in `:supported_locales`, fetched into
  # the on-disk cache by the `test` alias. Without that data Localize falls back
  # to `:und` and still returns `{:ok, ...}`, so these assertions would quietly
  # become "en output under a non-en locale name" rather than failing.

  # Grouping separators differ in *kind*, not just presence: fr uses a narrow
  # no-break space and ru a no-break space. Normalise them so the assertions read
  # as the reader expects while still proving the separator is a space and not a
  # comma or a dot.
  defp squish(string), do: String.replace(string, ~r/[\x{00A0}\x{202F}\x{2009}]/u, " ")

  describe "format/1,2 — value-dispatched formatting" do
    test "nil passes through" do
      assert AshLocalize.format(nil) == nil
      assert AshLocalize.format(nil, locale: "ja") == nil
    end

    test "an integer renders with locale-correct grouping separators" do
      assert AshLocalize.format(1_234_567) == "1,234,567"
      assert AshLocalize.format(1_234_567, locale: "en") == "1,234,567"
    end

    test "a Decimal renders locale-correctly" do
      assert AshLocalize.format(Decimal.new("1234.5")) == "1,234.5"
    end

    test "a Float renders locale-correctly" do
      assert AshLocalize.format(1234.5) == "1,234.5"
    end

    test "a %Money{} renders amount and currency together" do
      assert AshLocalize.format(Money.new(:USD, "1234.5")) == "$1,234.50"
      assert AshLocalize.format(Money.new(:JPY, 1500)) == "¥1,500"
    end

    test "a Date renders with locale-correct field ordering" do
      assert AshLocalize.format(~D[2026-05-22]) == "May 22, 2026"
    end

    test "a NaiveDateTime renders with locale-correct date+time" do
      formatted = AshLocalize.format(~N[2026-05-22 13:45:00])
      assert formatted =~ "May 22, 2026"
      assert formatted =~ "1:45:00"
    end

    test "a UTC DateTime renders with locale-correct date+time" do
      dt = DateTime.from_naive!(~N[2026-05-22 13:45:00], "Etc/UTC")
      assert AshLocalize.format(dt) =~ "May 22, 2026"
    end

    test "a list of strings renders with the locale-correct joiner" do
      assert AshLocalize.format(["apples", "oranges", "pears"]) == "apples, oranges, and pears"
    end

    test "an atom falls through to Kernel.to_string via the Localize.Chars Any fallback" do
      # Localize.Chars has @fallback_to_any — unknown types route through
      # Kernel.to_string rather than raising, which is the friendlier default.
      assert AshLocalize.format(:some_atom) == "some_atom"
    end
  end

  describe "format/2 with the optional satellite types" do
    test "a %Localize.PersonName{} renders locale-correctly" do
      {:ok, name} = Localize.PersonName.new(given_name: "Ada", surname: "Lovelace")
      assert AshLocalize.format(name) =~ "Ada"
    end
  end

  describe "format/2 with a Localize.Unit" do
    test "a %Localize.Unit{} renders with locale-correct number + unit" do
      {:ok, unit} = Localize.Unit.new(7800, "meter-per-second")
      formatted = AshLocalize.format(unit)
      assert is_binary(formatted)
      assert formatted =~ "7,800"
    end
  end

  describe "format/2 across locales" do
    test "integer grouping separators follow the locale" do
      for {locale, expected} <- [
            {"en", "1,234,567"},
            {"de", "1.234.567"},
            {"es", "1.234.567"},
            {"ja", "1,234,567"},
            {"fr", "1 234 567"},
            {"ru", "1 234 567"}
          ] do
        assert squish(AshLocalize.format(1_234_567, locale: locale)) == expected,
               "expected #{locale} to group as #{expected}"
      end
    end

    test "decimal separators follow the locale" do
      d = Decimal.new("1234.5")

      for {locale, expected} <- [
            {"en", "1,234.5"},
            {"de", "1.234,5"},
            {"fr", "1 234,5"},
            # es groups only from five digits, so there is no separator here at all
            {"es", "1234,5"},
            {"ru", "1 234,5"}
          ] do
        assert squish(AshLocalize.format(d, locale: locale)) == expected,
               "expected #{locale} to render #{expected}"
      end
    end

    test "dates follow locale field order and separators" do
      date = ~D[2026-05-22]

      for {locale, expected} <- [
            {"en", "May 22, 2026"},
            {"de", "22.05.2026"},
            {"fr", "22 mai 2026"},
            {"ja", "2026/05/22"},
            {"zh-Hant", "2026年5月22日"}
          ] do
        assert AshLocalize.format(date, locale: locale) == expected,
               "expected #{locale} to render #{expected}"
      end
    end

    test "lists take the locale's conjunction" do
      for {locale, expected} <- [
            {"en", "a, b, and c"},
            {"de", "a, b und c"},
            {"fr", "a, b et c"},
            {"es", "a, b y c"},
            {"ru", "a, b и c"},
            {"ja", "a、b、c"}
          ] do
        assert AshLocalize.format(["a", "b", "c"], locale: locale) == expected,
               "expected #{locale} to join as #{expected}"
      end
    end

    test "money places the currency symbol per locale convention" do
      money = Money.new(:USD, "1234.5")

      # en leads with the symbol, de trails it, zh-Hant leads with a distinct
      # display name for a foreign currency.
      assert AshLocalize.format(money, locale: "en") == "$1,234.50"
      assert squish(AshLocalize.format(money, locale: "de")) == "1.234,50 $"
      assert squish(AshLocalize.format(money, locale: "fr")) == "1 234,50 $US"
      assert AshLocalize.format(money, locale: "zh-Hant") == "US$1,234.50"
    end

    test "the locale data is really loaded" do
      # Canary for the setup itself. A missing cache makes Localize fall back to
      # :und while still returning {:ok, ...}, so every assertion above would
      # quietly become "en output under a non-en locale name" instead of failing.
      assert AshLocalize.format(1_234_567, locale: "de") !=
               AshLocalize.format(1_234_567, locale: "en")
    end
  end
end
