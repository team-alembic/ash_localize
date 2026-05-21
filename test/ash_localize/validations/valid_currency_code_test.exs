defmodule AshLocalize.Validations.ValidCurrencyCodeTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Test.Profile
  alias AshLocalize.Validations.ValidCurrencyCode

  describe "init/1" do
    test "requires an :attribute option" do
      assert {:error, _} = ValidCurrencyCode.init([])
    end

    test "accepts an atom :attribute option" do
      assert {:ok, opts} = ValidCurrencyCode.init(attribute: :raw_currency)
      assert opts[:attribute] == :raw_currency
    end
  end

  describe "validate/3" do
    test "passes a valid currency code" do
      changeset = Ash.Changeset.for_create(Profile, :create, %{raw_currency: "USD"})
      assert ValidCurrencyCode.validate(changeset, [attribute: :raw_currency], %{}) == :ok
    end

    test "fails an invalid currency code, reporting the attribute" do
      changeset = Ash.Changeset.for_create(Profile, :create, %{raw_currency: "GGG"})

      assert {:error, error} =
               ValidCurrencyCode.validate(changeset, [attribute: :raw_currency], %{})

      assert error[:field] == :raw_currency
    end

    test "passes when the attribute is nil" do
      changeset = Ash.Changeset.for_create(Profile, :create, %{})
      assert ValidCurrencyCode.validate(changeset, [attribute: :raw_currency], %{}) == :ok
    end
  end
end
