defmodule AshLocalize.Calculations.FormatAddressTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatAddress

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  defp address do
    %Localize.Address.Address{
      house_number: "1600",
      road: "Amphitheatre Parkway",
      city: "Mountain View",
      state: "CA",
      postcode: "94043",
      territory_code: "US"
    }
  end

  describe "init/1" do
    test "requires a :field option" do
      assert {:error, _} = FormatAddress.init([])
    end

    test "accepts a :field option" do
      assert {:ok, opts} = FormatAddress.init(field: :address)
      assert opts[:field] == :address
    end
  end

  describe "load/3" do
    test "loads the source field" do
      assert FormatAddress.load(nil, [field: :address], @context) == [:address]
    end
  end

  describe "calculate/3" do
    test "formats an address in the resolved locale" do
      assert FormatAddress.calculate([%{address: address()}], [field: :address], @context) ==
               ["1600 Amphitheatre Parkway\nMountain View, CA 94043"]
    end

    test "returns nil for a nil value" do
      assert FormatAddress.calculate([%{address: nil}], [field: :address], @context) == [nil]
    end
  end
end
