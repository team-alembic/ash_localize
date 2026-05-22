defmodule AshLocalize.Types.PersonNameTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.PersonName

  describe "cast_input/2" do
    test "casts a map of name parts into a PersonName struct" do
      assert {:ok, %Localize.PersonName{given_name: "Ada", surname: "Lovelace"}} =
               PersonName.cast_input(%{given_name: "Ada", surname: "Lovelace"}, [])
    end

    test "accepts string keys" do
      assert {:ok, %Localize.PersonName{given_name: "Ada", surname: "Lovelace"}} =
               PersonName.cast_input(%{"given_name" => "Ada", "surname" => "Lovelace"}, [])
    end

    test "accepts an existing PersonName struct" do
      {:ok, name} = Localize.PersonName.new(given_name: "Ada")
      assert PersonName.cast_input(name, []) == {:ok, name}
    end

    test "rejects a name without a given name" do
      assert {:error, _} = PersonName.cast_input(%{surname: "Valim"}, [])
    end

    test "rejects a non-map value" do
      assert {:error, _} = PersonName.cast_input("Ada Lovelace", [])
    end

    test "passes nil through" do
      assert PersonName.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "storage" do
    test "storage_type/1 is :map" do
      assert PersonName.storage_type([]) == :map
    end

    test "round-trips through dump_to_native/2 and cast_stored/2" do
      {:ok, name} =
        PersonName.cast_input(%{given_name: "Ada", surname: "Lovelace", title: "Dr."}, [])

      assert {:ok, dumped} = PersonName.dump_to_native(name, [])
      assert is_map(dumped)

      assert {:ok, %Localize.PersonName{given_name: "Ada", surname: "Lovelace", title: "Dr."}} =
               PersonName.cast_stored(dumped, [])

      assert PersonName.dump_to_native(nil, []) == {:ok, nil}
      assert PersonName.cast_stored(nil, []) == {:ok, nil}
    end
  end
end
