# These reference Localize.Address and Localize.PhoneNumber, which need system
# libraries that are opt-in — see native_deps/0 in mix.exs. They live in their own
# file because the compiler rejects references to a missing module even inside a
# test that would be excluded at runtime.
if Code.ensure_loaded?(Localize.Address) and Code.ensure_loaded?(Localize.PhoneNumber) do
  defmodule AshLocalize.FormatNativeTest do
    use ExUnit.Case, async: true

    @moduletag :native

    describe "format/2 with the native satellite types" do
      test "a %Localize.Address.Address{} renders multi-line" do
        # struct!/2 rather than a literal: this module also holds non-native tests,
        # so it must compile when Localize.Address is absent.
        address =
          struct!(Localize.Address.Address,
            road: "1 Infinite Loop",
            city: "Cupertino",
            state: "CA",
            postcode: "95014",
            territory_code: "US"
          )

        formatted = AshLocalize.format(address)
        assert is_binary(formatted)
        assert formatted =~ "Cupertino"
      end

      test "a %Localize.PhoneNumber.Number{} renders in :international format by default" do
        {:ok, number} = Localize.PhoneNumber.parse("+1 650 253 0000")
        assert AshLocalize.format(number) =~ "+1"
      end
    end
  end
end
