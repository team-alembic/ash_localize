defmodule AshLocalize.Types.LocaleTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Locale

  describe "cast_input/2" do
    test "casts a blank string to nil, as an unset form input submits" do
      assert Locale.cast_input("", []) == {:ok, nil}
      assert Locale.cast_input("  ", []) == {:ok, nil}
    end

    test "accepts a valid locale and canonicalises region casing" do
      assert Locale.cast_input("en-us", []) == {:ok, "en-US"}
    end

    test "canonicalises a language-only locale to lower case" do
      assert Locale.cast_input("EN", []) == {:ok, "en"}
    end

    test "preserves a script subtag" do
      assert Locale.cast_input("zh-Hant", []) == {:ok, "zh-Hant"}
    end

    test "rejects a malformed locale string" do
      assert {:error, _} = Locale.cast_input("!!!", [])
    end

    test "rejects a grammatically valid but unknown subtag" do
      assert {:error, _} = Locale.cast_input("xx", [])
    end

    test "rejects a non-string value" do
      assert {:error, _} = Locale.cast_input(123, [])
    end

    test "passes nil through" do
      assert Locale.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "as an Ash.Type" do
    test "storage_type/1 is :string" do
      assert Locale.storage_type([]) == :string
    end

    test "round-trips through cast_stored/2 and dump_to_native/2" do
      assert Locale.cast_stored("en-US", []) == {:ok, "en-US"}
      assert Locale.cast_stored(nil, []) == {:ok, nil}
      assert Locale.dump_to_native("en-US", []) == {:ok, "en-US"}
      assert Locale.dump_to_native(nil, []) == {:ok, nil}
    end

    test "is recognised by Ash.Type.cast_input/3" do
      assert Ash.Type.cast_input(Locale, "en-us", []) == {:ok, "en-US"}
    end
  end
end
