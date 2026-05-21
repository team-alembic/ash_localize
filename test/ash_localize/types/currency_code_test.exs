defmodule AshLocalize.Types.CurrencyCodeTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.CurrencyCode

  describe "cast_input/2" do
    test "accepts a currency code and upcases it" do
      assert CurrencyCode.cast_input("aud", []) == {:ok, "AUD"}
    end

    test "accepts an already-canonical currency code" do
      assert CurrencyCode.cast_input("USD", []) == {:ok, "USD"}
    end

    test "rejects an unknown currency code" do
      assert {:error, _} = CurrencyCode.cast_input("GGG", [])
    end

    test "rejects a non-string value" do
      assert {:error, _} = CurrencyCode.cast_input(123, [])
    end

    test "passes nil through" do
      assert CurrencyCode.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "as an Ash.Type" do
    test "storage_type/1 is :string" do
      assert CurrencyCode.storage_type([]) == :string
    end

    test "round-trips through cast_stored/2 and dump_to_native/2" do
      assert CurrencyCode.cast_stored("USD", []) == {:ok, "USD"}
      assert CurrencyCode.cast_stored(nil, []) == {:ok, nil}
      assert CurrencyCode.dump_to_native("USD", []) == {:ok, "USD"}
      assert CurrencyCode.dump_to_native(nil, []) == {:ok, nil}
    end

    test "is recognised by Ash.Type.cast_input/3" do
      assert Ash.Type.cast_input(CurrencyCode, "aud", []) == {:ok, "AUD"}
    end
  end
end
