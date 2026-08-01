defmodule AshLocalize.ErrorMessageTest do
  use ExUnit.Case, async: true

  describe "translate_error/2 — interpolation without translation" do
    test "a message with no variables passes through" do
      assert AshLocalize.translate_error({"must be present", []}, locale: "de") ==
               "must be present"
    end

    test "a bare string is accepted as a message with no variables" do
      assert AshLocalize.translate_error("cannot be changed", locale: "fr") ==
               "cannot be changed"
    end

    test "numeric variables are formatted in the locale" do
      # Ash's own decimal.ex and float.ex pass raw numbers into this msgid, so a
      # de-DE user currently reads 1234.5 where they expect 1.234,5.
      msg = {"must be less than or equal to %{max}", max: Decimal.new("1234.5")}

      assert AshLocalize.translate_error(msg, locale: "en") ==
               "must be less than or equal to 1,234.5"

      assert AshLocalize.translate_error(msg, locale: "de") ==
               "must be less than or equal to 1.234,5"
    end

    test "integers are grouped in the locale" do
      msg = {"must have %{max} or fewer items", max: 1_234_567}

      assert AshLocalize.translate_error(msg, locale: "en") ==
               "must have 1,234,567 or fewer items"

      assert AshLocalize.translate_error(msg, locale: "de") ==
               "must have 1.234.567 or fewer items"
    end

    test "a list variable takes the locale's conjunction" do
      msg = {"at least %{at_least} of %{keys} must be present", at_least: 3, keys: ~w[a b c]}

      assert AshLocalize.translate_error(msg, locale: "en") ==
               "at least 3 of a, b, and c must be present"

      assert AshLocalize.translate_error(msg, locale: "de") ==
               "at least 3 of a, b und c must be present"

      assert AshLocalize.translate_error(msg, locale: "es") ==
               "at least 3 of a, b y c must be present"
    end

    test "a pre-joined string variable is passed through untouched" do
      # Ash bakes the English comma in before we ever see the message —
      # `Enum.join(opts[:attributes], ", ")` in present.ex. Nothing downstream can
      # recover the list, so we must not guess by splitting on ", ".
      msg = {"at least %{at_least} of %{keys} must be present", at_least: 3, keys: "a, b, c"}

      assert AshLocalize.translate_error(msg, locale: "de") ==
               "at least 3 of a, b, c must be present"
    end

    test "atoms and strings interpolate as themselves" do
      msg = {"must be %{action}", action: :read}
      assert AshLocalize.translate_error(msg, locale: "de") == "must be read"
    end

    test "a variable with no matching binding is left alone" do
      assert AshLocalize.translate_error({"must equal %{value}", []}, locale: "en") ==
               "must equal %{value}"
    end

    test "vars are accepted as a map as well as a keyword list" do
      msg = {"must have %{max} or fewer items", %{max: 1234}}
      assert AshLocalize.translate_error(msg, locale: "de") == "must have 1.234 or fewer items"
    end
  end

  describe "translate_error/2 — Ash error structs" do
    test "an error struct carrying :message and :vars is translated" do
      error = %{message: "must have %{max} or fewer items", vars: [max: 1234]}
      assert AshLocalize.translate_error(error, locale: "de") == "must have 1.234 or fewer items"
    end

    test "a real Ash.Error.Changes.InvalidAttribute is translated" do
      error =
        Ash.Error.Changes.InvalidAttribute.exception(
          field: :count,
          message: "must be less than or equal to %{max}",
          vars: [max: 1234]
        )

      assert AshLocalize.translate_error(error, locale: "de") ==
               "must be less than or equal to 1.234"
    end
  end

  describe "translate_error/2 — locale resolution" do
    test "falls back to the application default when no locale is given" do
      assert AshLocalize.translate_error({"must have %{max} or fewer items", max: 1234}) ==
               "must have 1,234 or fewer items"
    end
  end
end
