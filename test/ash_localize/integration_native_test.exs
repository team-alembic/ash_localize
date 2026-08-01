# The phone-number and postal-address halves of the integration suite. They need
# libphonenumber and libpostal, which are opt-in — see native_deps/0 in mix.exs —
# and the compiler rejects references to a missing module even in a test that
# would be excluded at runtime, so they are guarded rather than only tagged.
if Code.ensure_loaded?(Localize.Address) and Code.ensure_loaded?(Localize.PhoneNumber) do
  defmodule AshLocalize.IntegrationNativeTest do
    use ExUnit.Case, async: true

    @moduletag :native

    alias AshLocalize.Test.Profile

    defp create(params) do
      Profile
      |> Ash.Changeset.for_create(:create, params)
      |> Ash.create()
    end

    describe "the PhoneNumber type and FormatPhone" do
      test "parses, stores, and formats a phone number" do
        {:ok, profile} = create(%{contact_phone: "+1 650-253-0000"})
        assert %Localize.PhoneNumber.Number{} = profile.contact_phone

        {:ok, reloaded} = Ash.get(Profile, profile.id)
        assert %Localize.PhoneNumber.Number{} = reloaded.contact_phone

        {:ok, loaded} = Ash.load(reloaded, [:formatted_phone])
        assert loaded.formatted_phone == "+1 650-253-0000"
      end

      test "rejects an invalid phone number" do
        assert {:error, %Ash.Error.Invalid{errors: errors}} =
                 create(%{contact_phone: "not a phone number"})

        assert Enum.any?(errors, &match?(%{field: :contact_phone}, &1))
      end
    end

    describe "the PostalAddress type and FormatAddress" do
      test "casts a component map, stores it, and formats it" do
        {:ok, profile} =
          create(%{
            shipping_address: %{
              house_number: "1600",
              road: "Amphitheatre Parkway",
              city: "Mountain View",
              state: "CA",
              postcode: "94043",
              territory_code: "US"
            }
          })

        {:ok, reloaded} = Ash.get(Profile, profile.id)
        assert %Localize.Address.Address{city: "Mountain View"} = reloaded.shipping_address

        {:ok, loaded} = Ash.load(reloaded, [:formatted_address])
        assert loaded.formatted_address == "1600 Amphitheatre Parkway\nMountain View, CA 94043"
      end
    end
  end
end
