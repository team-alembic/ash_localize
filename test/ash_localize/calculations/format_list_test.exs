defmodule AshLocalize.Calculations.FormatListTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatList

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires a :field option" do
      assert {:error, _} = FormatList.init([])
    end

    test "accepts a :field option" do
      assert {:ok, opts} = FormatList.init(field: :tags)
      assert opts[:field] == :tags
    end
  end

  describe "load/3" do
    test "loads the source field" do
      assert FormatList.load(nil, [field: :tags], @context) == [:tags]
    end
  end

  describe "calculate/3" do
    test "joins a list with locale-appropriate conjunctions" do
      records = [%{tags: ["apples", "oranges", "pears"]}]

      assert FormatList.calculate(records, [field: :tags], @context) ==
               ["apples, oranges, and pears"]
    end

    test "formats a single-element list" do
      assert FormatList.calculate([%{tags: ["solo"]}], [field: :tags], @context) == ["solo"]
    end

    test "formats an empty list as an empty string" do
      assert FormatList.calculate([%{tags: []}], [field: :tags], @context) == [""]
    end

    test "returns nil for a nil value" do
      assert FormatList.calculate([%{tags: nil}], [field: :tags], @context) == [nil]
    end
  end
end
