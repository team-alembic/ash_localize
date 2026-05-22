defmodule AshLocalize.Types.PostalAddressTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.PostalAddress

  describe "cast_input/2" do
    test "casts a map of components into an Address struct" do
      assert {:ok, %Localize.Address.Address{house_number: "1600", city: "Mountain View"}} =
               PostalAddress.cast_input(
                 %{house_number: "1600", road: "Amphitheatre Parkway", city: "Mountain View"},
                 []
               )
    end

    test "accepts string keys" do
      assert {:ok, %Localize.Address.Address{city: "Mountain View"}} =
               PostalAddress.cast_input(%{"city" => "Mountain View"}, [])
    end

    test "accepts an existing Address struct" do
      address = %Localize.Address.Address{city: "Mountain View"}
      assert PostalAddress.cast_input(address, []) == {:ok, address}
    end

    test "rejects a map with no recognised address components" do
      assert {:error, _} = PostalAddress.cast_input(%{nonsense: "value"}, [])
    end

    test "rejects a non-map value" do
      assert {:error, _} = PostalAddress.cast_input("1600 Amphitheatre Pkwy", [])
    end

    test "passes nil through" do
      assert PostalAddress.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "storage" do
    test "storage_type/1 is :map" do
      assert PostalAddress.storage_type([]) == :map
    end

    test "round-trips through dump_to_native/2 and cast_stored/2" do
      {:ok, address} =
        PostalAddress.cast_input(%{house_number: "1600", city: "Mountain View"}, [])

      assert {:ok, dumped} = PostalAddress.dump_to_native(address, [])
      assert is_map(dumped)

      assert {:ok, %Localize.Address.Address{house_number: "1600", city: "Mountain View"}} =
               PostalAddress.cast_stored(dumped, [])

      assert PostalAddress.dump_to_native(nil, []) == {:ok, nil}
      assert PostalAddress.cast_stored(nil, []) == {:ok, nil}
    end
  end
end
