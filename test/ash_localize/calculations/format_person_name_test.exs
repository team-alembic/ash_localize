defmodule AshLocalize.Calculations.FormatPersonNameTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatPersonName

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  defp ada do
    {:ok, name} = Localize.PersonName.new(given_name: "Ada", surname: "Lovelace", title: "Dr.")
    name
  end

  describe "init/1" do
    test "requires a :field option" do
      assert {:error, _} = FormatPersonName.init([])
    end

    test "accepts a :field option" do
      assert {:ok, opts} = FormatPersonName.init(field: :name)
      assert opts[:field] == :name
    end
  end

  describe "load/3" do
    test "loads the source field" do
      assert FormatPersonName.load(nil, [field: :name], @context) == [:name]
    end
  end

  describe "calculate/3" do
    test "formats a person name in the resolved locale" do
      assert FormatPersonName.calculate([%{name: ada()}], [field: :name], @context) == ["Ada"]
    end

    test "passes formatting options through to Localize" do
      opts = [field: :name, usage: :referring]
      assert FormatPersonName.calculate([%{name: ada()}], opts, @context) == ["Ada Lovelace"]
    end

    test "returns nil for a nil value" do
      assert FormatPersonName.calculate([%{name: nil}], [field: :name], @context) == [nil]
    end
  end
end
