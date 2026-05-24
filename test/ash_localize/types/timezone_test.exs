defmodule AshLocalize.Types.TimezoneTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Timezone

  describe "cast_input/2" do
    test "accepts a canonical IANA timezone name and passes it through" do
      assert Timezone.cast_input("Australia/Sydney", []) == {:ok, "Australia/Sydney"}
    end

    test "canonicalises an IANA alias to the CLDR-preferred IANA name" do
      # `Australia/ACT` is an alias of `ausyd` whose first/preferred IANA name
      # is `Australia/Sydney`.
      assert Timezone.cast_input("Australia/ACT", []) == {:ok, "Australia/Sydney"}
    end

    test "accepts a BCP 47 short zone code and canonicalises to IANA" do
      assert Timezone.cast_input("ausyd", []) == {:ok, "Australia/Sydney"}
    end

    test "accepts UTC under any alias" do
      assert {:ok, canonical} = Timezone.cast_input("UTC", [])
      assert canonical in ["Etc/UTC", "UTC"]

      assert {:ok, ^canonical} = Timezone.cast_input("Etc/UTC", [])
      assert {:ok, ^canonical} = Timezone.cast_input("utc", [])
    end

    test "rejects an unknown timezone" do
      assert {:error, _} = Timezone.cast_input("Nope/Nowhere", [])
    end

    test "rejects a non-string value" do
      assert {:error, _} = Timezone.cast_input(123, [])
    end

    test "passes nil through" do
      assert Timezone.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "as an Ash.Type" do
    test "storage_type/1 is :string" do
      assert Timezone.storage_type([]) == :string
    end

    test "round-trips through cast_stored/2 and dump_to_native/2" do
      assert Timezone.cast_stored("Australia/Sydney", []) == {:ok, "Australia/Sydney"}
      assert Timezone.cast_stored(nil, []) == {:ok, nil}
      assert Timezone.dump_to_native("Australia/Sydney", []) == {:ok, "Australia/Sydney"}
      assert Timezone.dump_to_native(nil, []) == {:ok, nil}
    end

    test "is recognised by Ash.Type.cast_input/3" do
      assert Ash.Type.cast_input(Timezone, "Australia/ACT", []) == {:ok, "Australia/Sydney"}
    end
  end
end
