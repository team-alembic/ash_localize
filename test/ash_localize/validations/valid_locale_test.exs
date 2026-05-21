defmodule AshLocalize.Validations.ValidLocaleTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Test.Profile
  alias AshLocalize.Validations.ValidLocale

  describe "init/1" do
    test "requires an :attribute option" do
      assert {:error, _} = ValidLocale.init([])
    end

    test "rejects a non-atom :attribute option" do
      assert {:error, _} = ValidLocale.init(attribute: "raw_locale")
    end

    test "accepts an atom :attribute option" do
      assert {:ok, opts} = ValidLocale.init(attribute: :raw_locale)
      assert opts[:attribute] == :raw_locale
    end
  end

  describe "validate/3" do
    test "passes a valid locale" do
      changeset = Ash.Changeset.for_create(Profile, :create, %{raw_locale: "en-US"})
      assert ValidLocale.validate(changeset, [attribute: :raw_locale], %{}) == :ok
    end

    test "fails an invalid locale, reporting the attribute" do
      changeset = Ash.Changeset.for_create(Profile, :create, %{raw_locale: "!!!"})
      assert {:error, error} = ValidLocale.validate(changeset, [attribute: :raw_locale], %{})
      assert error[:field] == :raw_locale
    end

    test "passes when the attribute is nil" do
      changeset = Ash.Changeset.for_create(Profile, :create, %{})
      assert ValidLocale.validate(changeset, [attribute: :raw_locale], %{}) == :ok
    end
  end
end
