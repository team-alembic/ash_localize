defmodule AshLocalize.IntegrationTest do
  @moduledoc """
  Exercises the Phase 1 types and validations through real Ash actions on the
  `AshLocalize.Test.Profile` resource.
  """
  use ExUnit.Case, async: true

  alias AshLocalize.Test.Profile

  defp create(params) do
    Profile
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create()
  end

  describe "custom types on a resource" do
    test "valid values are cast and stored in canonical form" do
      assert {:ok, profile} =
               create(%{locale: "en-us", territory: "au", currency_code: "aud"})

      assert profile.locale == "en-US"
      assert profile.territory == "AU"
      assert profile.currency_code == "AUD"
    end

    test "stored values survive a data-layer round trip" do
      assert {:ok, created} = create(%{locale: "pt-br"})
      assert {:ok, reloaded} = Ash.get(Profile, created.id)
      assert reloaded.locale == "pt-BR"
    end

    test "an invalid locale is rejected, naming the offending attribute" do
      assert {:error, %Ash.Error.Invalid{errors: errors}} = create(%{locale: "!!!"})
      assert Enum.any?(errors, &match?(%{field: :locale}, &1))
    end

    test "an invalid currency code is rejected" do
      assert {:error, %Ash.Error.Invalid{errors: errors}} = create(%{currency_code: "GGG"})
      assert Enum.any?(errors, &match?(%{field: :currency_code}, &1))
    end
  end

  describe "validations on plain string attributes" do
    test "valid values pass" do
      assert {:ok, _profile} =
               create(%{raw_locale: "en-US", raw_territory: "AU", raw_currency: "USD"})
    end

    test "an invalid raw locale is rejected, naming the offending attribute" do
      assert {:error, %Ash.Error.Invalid{errors: errors}} = create(%{raw_locale: "!!!"})
      assert Enum.any?(errors, &match?(%{field: :raw_locale}, &1))
    end

    test "an invalid raw territory is rejected" do
      assert {:error, %Ash.Error.Invalid{errors: errors}} = create(%{raw_territory: "ZZZZ"})
      assert Enum.any?(errors, &match?(%{field: :raw_territory}, &1))
    end
  end
end
