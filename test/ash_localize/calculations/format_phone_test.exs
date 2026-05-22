defmodule AshLocalize.Calculations.FormatPhoneTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatPhone

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  defp number do
    {:ok, parsed} = Localize.PhoneNumber.parse("+1 650-253-0000")
    parsed
  end

  describe "init/1" do
    test "requires a :field option" do
      assert {:error, _} = FormatPhone.init([])
    end

    test "accepts a :field option" do
      assert {:ok, opts} = FormatPhone.init(field: :phone)
      assert opts[:field] == :phone
    end
  end

  describe "load/3" do
    test "loads the source field" do
      assert FormatPhone.load(nil, [field: :phone], @context) == [:phone]
    end
  end

  describe "calculate/3" do
    test "formats a phone number in the international style by default" do
      assert FormatPhone.calculate([%{phone: number()}], [field: :phone], @context) ==
               ["+1 650-253-0000"]
    end

    test "supports the :format style option" do
      opts = [field: :phone, format: :national]
      assert FormatPhone.calculate([%{phone: number()}], opts, @context) == ["(650) 253-0000"]
    end

    test "returns nil for a nil value" do
      assert FormatPhone.calculate([%{phone: nil}], [field: :phone], @context) == [nil]
    end
  end
end
