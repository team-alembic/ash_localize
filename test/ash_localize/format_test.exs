defmodule AshLocalize.FormatTest do
  use ExUnit.Case, async: true

  # Only :en is loaded by default in this test env. The :locale opt is plumbed
  # through to Localize on every implementation, but exercising non-en locales
  # requires explicit locale-data loading (see README for production setup), so
  # the assertions below stay in :en.

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

    test "raises Protocol.UndefinedError for an unformattable value" do
      assert_raise Protocol.UndefinedError, fn ->
        AshLocalize.format(:some_atom)
      end
    end
  end

  describe "format/2 with the optional satellite types" do
    test "a %Localize.PersonName{} renders locale-correctly" do
      {:ok, name} = Localize.PersonName.new(given_name: "Ada", surname: "Lovelace")
      assert AshLocalize.format(name) =~ "Ada"
    end

    test "a %Localize.Address.Address{} renders multi-line" do
      address = %Localize.Address.Address{
        road: "1 Infinite Loop",
        city: "Cupertino",
        state: "CA",
        postcode: "95014",
        territory_code: "US"
      }

      formatted = AshLocalize.format(address)
      assert is_binary(formatted)
      assert formatted =~ "Cupertino"
    end

    test "a %Localize.PhoneNumber.Number{} renders in :international format by default" do
      {:ok, number} = Localize.PhoneNumber.parse("+1 650 253 0000")
      assert AshLocalize.format(number) =~ "+1"
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
end
