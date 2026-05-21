defmodule AshLocalize.Validations.ValidTerritoryTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Test.Profile
  alias AshLocalize.Validations.ValidTerritory

  describe "init/1" do
    test "requires an :attribute option" do
      assert {:error, _} = ValidTerritory.init([])
    end

    test "accepts an atom :attribute option" do
      assert {:ok, opts} = ValidTerritory.init(attribute: :raw_territory)
      assert opts[:attribute] == :raw_territory
    end
  end

  describe "validate/3" do
    test "passes a valid territory" do
      changeset = Ash.Changeset.for_create(Profile, :create, %{raw_territory: "AU"})
      assert ValidTerritory.validate(changeset, [attribute: :raw_territory], %{}) == :ok
    end

    test "fails an invalid territory, reporting the attribute" do
      changeset = Ash.Changeset.for_create(Profile, :create, %{raw_territory: "ZZZZ"})

      assert {:error, error} =
               ValidTerritory.validate(changeset, [attribute: :raw_territory], %{})

      assert error[:field] == :raw_territory
    end

    test "passes when the attribute is nil" do
      changeset = Ash.Changeset.for_create(Profile, :create, %{})
      assert ValidTerritory.validate(changeset, [attribute: :raw_territory], %{}) == :ok
    end
  end
end
