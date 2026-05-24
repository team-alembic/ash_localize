defmodule AshLocalize.Calculations.FormatCountTest do
  use ExUnit.Case, async: true

  alias AshLocalize.Calculations.FormatCount

  @context %{arguments: %{}, source_context: %{}, actor: nil}

  describe "init/1" do
    test "requires :field" do
      assert {:error, _} = FormatCount.init(one: "1 thing", other: "many things")
    end

    test "requires either :template or plural forms" do
      assert {:error, _} = FormatCount.init(field: :n)
    end

    test "accepts :field with :one/:other and assembles an MF2 template" do
      assert {:ok, opts} =
               FormatCount.init(field: :n, one: "1 comment", other: "{$count} comments")

      assert opts[:template_string] =~ "{{1 comment}}"
      assert opts[:template_string] =~ "{{{$count} comments}}"
    end

    test "accepts a raw :template" do
      template = ".input {$count :integer}\n.match $count\n* {{{$count} foo}}"
      assert {:ok, opts} = FormatCount.init(field: :n, template: template)
      assert opts[:template_string] == template
    end
  end

  describe "calculate/3" do
    test "renders plural-aware English with :if_zero / :one / :other" do
      {:ok, opts} =
        FormatCount.init(
          field: :n,
          if_zero: "No comments",
          one: "1 comment",
          other: "{$count} comments"
        )

      records = [%{n: 0}, %{n: 1}, %{n: 5}]

      assert FormatCount.calculate(records, opts, @context) ==
               ["No comments", "1 comment", "5 comments"]
    end

    test "returns nil for nil values" do
      {:ok, opts} = FormatCount.init(field: :n, one: "1 c", other: "{$count} cs")
      assert FormatCount.calculate([%{n: nil}], opts, @context) == [nil]
    end
  end
end
