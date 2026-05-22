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

  describe "formatting calculations" do
    test "render their source attributes in the resolved locale" do
      {:ok, profile} =
        create(%{
          price: Decimal.new("1234.5"),
          currency: "USD",
          event_date: ~D[2026-05-22],
          event_at: ~U[2026-05-22 13:45:00Z],
          tags: ["apples", "oranges", "pears"]
        })

      {:ok, loaded} =
        Ash.load(profile, [
          :formatted_price,
          :formatted_price_usd,
          :formatted_price_dynamic,
          :formatted_event_date,
          :formatted_event_at,
          :formatted_tags
        ])

      assert loaded.formatted_price == "1,234.5"
      assert loaded.formatted_price_usd == "$1,234.50"
      assert loaded.formatted_price_dynamic == "$1,234.50"
      assert loaded.formatted_event_date == "May 22, 2026"
      assert String.starts_with?(loaded.formatted_event_at, "May 22, 2026, 1:45:00")
      assert loaded.formatted_tags == "apples, oranges, and pears"
    end

    test "yield nil when their source attribute is nil" do
      {:ok, profile} = create(%{})

      {:ok, loaded} =
        Ash.load(profile, [:formatted_price, :formatted_event_date, :formatted_tags])

      assert loaded.formatted_price == nil
      assert loaded.formatted_event_date == nil
      assert loaded.formatted_tags == nil
    end
  end

  describe "unit category types and FormatUnit" do
    test "casts a quantity, converting to the base unit, and formats it" do
      {:ok, profile} = create(%{delta_v: {2, "kilometer-per-second"}})

      # stored as a plain number, reloaded as a unit-aware quantity
      {:ok, reloaded} = Ash.get(Profile, profile.id)
      assert %Localize.Unit{name: "meter-per-second"} = reloaded.delta_v

      {:ok, loaded} = Ash.load(reloaded, [:formatted_delta_v])
      assert loaded.formatted_delta_v == "2,000 meters per second"
    end

    test "rejects a dimensionally incompatible unit" do
      assert {:error, %Ash.Error.Invalid{errors: errors}} = create(%{delta_v: {5, "kilogram"}})
      assert Enum.any?(errors, &match?(%{field: :delta_v}, &1))
    end
  end
end
