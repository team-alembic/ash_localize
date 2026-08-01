# Localize.PhoneNumber needs a system library that is opt-in — see native_deps/0 in mix.exs.
# The tag excludes these at runtime; the guard stops them being compiled at all.
if Code.ensure_loaded?(Localize.PhoneNumber) do
  defmodule AshLocalize.Types.PhoneNumberTest do
    use ExUnit.Case, async: true

    # Needs libphonenumber / libpostal — see native_deps/0 in mix.exs.
    @moduletag :native

    alias AshLocalize.Types.PhoneNumber

    describe "cast_input/2" do
      test "parses a valid phone number" do
        assert {:ok, %Localize.PhoneNumber.Number{}} =
                 PhoneNumber.cast_input("+1 650-253-0000", [])
      end

      test "accepts an already-parsed number" do
        {:ok, number} = Localize.PhoneNumber.parse("+1 650-253-0000")
        assert PhoneNumber.cast_input(number, []) == {:ok, number}
      end

      test "rejects an unparseable string" do
        assert {:error, _} = PhoneNumber.cast_input("not a number", [])
      end

      test "rejects a parseable but invalid number" do
        assert {:error, _} = PhoneNumber.cast_input("+1 555", [])
      end

      test "passes nil through" do
        assert PhoneNumber.cast_input(nil, []) == {:ok, nil}
      end
    end

    describe "storage" do
      test "storage_type/1 is :string" do
        assert PhoneNumber.storage_type([]) == :string
      end

      test "dumps to an E.164 string and re-parses on load" do
        {:ok, number} = PhoneNumber.cast_input("+1 650-253-0000", [])
        assert PhoneNumber.dump_to_native(number, []) == {:ok, "+16502530000"}

        assert {:ok, %Localize.PhoneNumber.Number{}} = PhoneNumber.cast_stored("+16502530000", [])

        assert PhoneNumber.dump_to_native(nil, []) == {:ok, nil}
        assert PhoneNumber.cast_stored(nil, []) == {:ok, nil}
      end
    end
  end
end
