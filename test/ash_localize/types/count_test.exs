defmodule AshLocalize.Types.CountTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Types.Count

  describe "cast_input/2" do
    test "accepts a non-negative integer" do
      assert Count.cast_input(0, []) == {:ok, 0}
      assert Count.cast_input(5, []) == {:ok, 5}
    end

    test "rejects non-integers" do
      assert {:error, _} = Count.cast_input("5", [])
      assert {:error, _} = Count.cast_input(1.5, [])
    end

    test "passes nil through" do
      assert Count.cast_input(nil, []) == {:ok, nil}
    end
  end

  describe "apply_constraints/2" do
    test "respects the default min (0)" do
      assert :ok = Count.apply_constraints(0, min: 0)
      assert :ok = Count.apply_constraints(5, min: 0)
      assert {:error, _} = Count.apply_constraints(-1, min: 0)
    end

    test "respects a custom max" do
      assert :ok = Count.apply_constraints(5, min: 0, max: 10)
      assert {:error, _} = Count.apply_constraints(11, min: 0, max: 10)
    end

    test "respects zero?: false" do
      assert :ok = Count.apply_constraints(1, min: 0, zero?: false)
      assert {:error, _} = Count.apply_constraints(0, min: 0, zero?: false)
    end

    test "passes nil through" do
      assert :ok = Count.apply_constraints(nil, [])
    end
  end

  describe "storage" do
    test "storage_type/1 is :integer" do
      assert Count.storage_type([]) == :integer
    end

    test "round-trips through dump_to_native/2 and cast_stored/2" do
      assert Count.dump_to_native(7, []) == {:ok, 7}
      assert Count.cast_stored(7, []) == {:ok, 7}
      assert Count.dump_to_native(nil, []) == {:ok, nil}
      assert Count.cast_stored(nil, []) == {:ok, nil}
    end
  end
end
