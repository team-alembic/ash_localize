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

    test "casts blank string parts to nil" do
      assert {:ok, %Localize.PersonName{given_name: "Ada", surname: nil}} =
               PersonName.cast_input(%{"given_name" => "Ada", "surname" => ""}, [])

      assert {:ok, %Localize.PersonName{surname: nil}} =
               PersonName.cast_input(%{"given_name" => "Ada", "surname" => "  "}, [])
    end

    test "casts a map whose parts are all blank to nil" do
      assert PersonName.cast_input(%{"given_name" => "", "surname" => " "}, []) == {:ok, nil}
      assert PersonName.cast_input(%{}, []) == {:ok, nil}
    end

    test "still requires a given name when another part is filled in" do
      assert {:error, _} = PersonName.cast_input(%{"given_name" => "", "surname" => "Hopper"}, [])
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

    test "round-trips a name with its own locale through JSON storage" do
      {:ok, name} =
        PersonName.cast_input(%{given_name: "Hayao", surname: "Miyazaki", locale: "ja"}, [])

      loaded = json_round_trip(name)

      assert %Localize.PersonName{given_name: "Hayao", locale: %Localize.LanguageTag{}} = loaded
      assert Localize.LanguageTag.to_string(loaded.locale) == "ja"
      assert {:ok, _formatted} = Localize.PersonName.to_string(loaded, locale: "en")
    end

    test "round-trips a preferred order through JSON storage" do
      {:ok, name} =
        PersonName.cast_input(
          %{given_name: "Ada", surname: "Lovelace", preferred_order: :surname_first},
          []
        )

      loaded = json_round_trip(name)

      assert %Localize.PersonName{preferred_order: :surname_first} = loaded
      assert {:ok, _formatted} = Localize.PersonName.to_string(loaded, locale: "en")
    end

    test "loads an atom-keyed stored map" do
      stored = %{given_name: "Ada", preferred_order: "surname_first", locale: "ja"}

      assert {:ok,
              %Localize.PersonName{
                preferred_order: :surname_first,
                locale: %Localize.LanguageTag{}
              }} =
               PersonName.cast_stored(stored, [])
    end

    test "rejects an unknown stored preferred order" do
      assert PersonName.cast_stored(
               %{"given_name" => "Ada", "preferred_order" => "backwards"},
               []
             ) ==
               :error
    end
  end

  defp json_round_trip(name) do
    {:ok, dumped} = PersonName.dump_to_native(name, [])
    {:ok, loaded} = dumped |> Jason.encode!() |> Jason.decode!() |> PersonName.cast_stored([])
    loaded
  end
end
