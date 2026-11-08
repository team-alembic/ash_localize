defmodule AshLocalize.JsonRoundtripTest do
  use ExUnit.Case, async: true

  # Ash.Signals and embedded resources dump a value to JSON and load it back
  # through cast_stored/2.
  defp roundtrip(type, value, constraints) do
    {:ok, dumped} = Ash.Type.dump_to_embedded(type, value, constraints)
    json = dumped |> Jason.encode!() |> Jason.decode!()
    Ash.Type.cast_stored(type, json, constraints)
  end

  for type <- [:percentage, :ratio] do
    test "#{type} survives a JSON roundtrip" do
      {:ok, constraints} = Ash.Type.init(unquote(type), [])
      value = Decimal.new("0.375")

      assert {:ok, loaded} = roundtrip(unquote(type), value, constraints)
      assert Decimal.equal?(loaded, value)
    end

    test "#{type} refuses a stored non-finite string" do
      {:ok, constraints} = Ash.Type.init(unquote(type), [])

      for text <- ["NaN", "Infinity", "-Infinity"] do
        assert :error = Ash.Type.cast_stored(unquote(type), text, constraints)
      end
    end

    test "#{type} loads a stored integer, float and nil" do
      {:ok, constraints} = Ash.Type.init(unquote(type), [])

      assert {:ok, %Decimal{}} = Ash.Type.cast_stored(unquote(type), 1, constraints)
      assert {:ok, %Decimal{}} = Ash.Type.cast_stored(unquote(type), 0.5, constraints)
      assert {:ok, nil} = Ash.Type.cast_stored(unquote(type), nil, constraints)
    end

    test "#{type} refuses a non-numeric stored string" do
      {:ok, constraints} = Ash.Type.init(unquote(type), [])
      assert :error = Ash.Type.cast_stored(unquote(type), "abc", constraints)
    end
  end

  test "a unit quantity survives a JSON roundtrip" do
    {:ok, constraints} = Ash.Type.init(:length, [])
    {:ok, value} = Ash.Type.cast_input(:length, Decimal.new("12.5"), constraints)

    assert {:ok, loaded} = roundtrip(:length, value, constraints)
    assert loaded.name == value.name

    assert Decimal.equal?(
             Decimal.new(to_string(loaded.value)),
             Decimal.new(to_string(value.value))
           )
  end

  test "a unit type refuses a stored non-finite string" do
    {:ok, constraints} = Ash.Type.init(:length, [])

    for text <- ["NaN", "Infinity", "-Infinity", "abc"] do
      assert :error = Ash.Type.cast_stored(:length, text, constraints)
    end
  end
end
