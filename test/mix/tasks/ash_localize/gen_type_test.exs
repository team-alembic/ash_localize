defmodule Mix.Tasks.AshLocalize.Gen.TypeTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  defp gen(args), do: test_project() |> Igniter.compose_task("ash_localize.gen.type", args)

  defp generated(igniter, path) do
    igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
  end

  # A generator that emits code which does not compile is worse than no generator,
  # and asserting on the diff text cannot catch it. Compile what comes out.
  defp assert_compiles(source, module) do
    # `use Ash.Type` emits a nested EctoType alongside the type itself, so check
    # for membership rather than matching the head of the list.
    modules = source |> Code.compile_string() |> Enum.map(&elem(&1, 0))
    assert module in modules

    Enum.each(modules, fn m ->
      :code.purge(m)
      :code.delete(m)
    end)
  end

  describe "--kind code" do
    test "generates a type built on AshLocalize.CodeType" do
      diff = gen(["MyApp.Types.Script", "--kind", "code"]) |> diff()

      assert diff =~ "defmodule MyApp.Types.Script do"
      assert diff =~ ~s(use AshLocalize.CodeType, message: "is not a valid script")
      assert diff =~ "def cast_code(value, _constraints) do"
    end

    test "wires up the validator when one is named" do
      diff =
        gen(["MyApp.Types.Script", "--kind", "code", "--validator", "Localize.validate_script"])
        |> diff()

      assert diff =~ "case Localize.validate_script(value) do"
      assert diff =~ "{:ok, code} -> {:ok, to_string(code)}"
      assert diff =~ "{:error, _reason} -> code_error()"
      refute diff =~ "TODO"
    end

    test "leaves a TODO body when no validator is given" do
      diff = gen(["MyApp.Types.Script", "--kind", "code"]) |> diff()
      assert diff =~ "# TODO: validate `value`"
    end
  end

  describe "--kind quantity" do
    test "defaults to decimal storage" do
      diff = gen(["MyApp.Types.Probability", "--kind", "quantity"]) |> diff()

      assert diff =~ "use AshLocalize.QuantityType"
      assert diff =~ "storage: :decimal"
      refute diff =~ "min:"
    end

    test "declares the bounds it is given" do
      diff =
        gen(["MyApp.Types.Probability", "--kind", "quantity", "--min", "0.0", "--max", "1.0"])
        |> diff()

      assert diff =~ "min: 0.0"
      assert diff =~ "max: 1.0"
    end

    test "takes integer storage" do
      diff =
        gen(["MyApp.Types.Attempts", "--kind", "quantity", "--storage", "integer", "--min", "0"])
        |> diff()

      assert diff =~ "storage: :integer"
      assert diff =~ "min: 0"
    end
  end

  describe "short names" do
    test "registers the short name when asked" do
      diff = gen(["MyApp.Types.Script", "--kind", "code", "-s", "script"]) |> diff()
      assert diff =~ "script: MyApp.Types.Script"
    end

    test "does not touch config when not asked" do
      diff = gen(["MyApp.Types.Script", "--kind", "code"]) |> diff()
      refute diff =~ "custom_types"
    end
  end

  describe "the generated code compiles" do
    test "a code type with a validator" do
      gen(["MyApp.Types.Script", "--kind", "code", "--validator", "Localize.validate_script"])
      |> generated("lib/my_app/types/script.ex")
      |> assert_compiles(MyApp.Types.Script)
    end

    test "a code type with the TODO body" do
      gen(["MyApp.Types.Currency2", "--kind", "code"])
      |> generated("lib/my_app/types/currency2.ex")
      |> assert_compiles(MyApp.Types.Currency2)
    end

    test "a bounded decimal quantity" do
      gen(["MyApp.Types.Probability", "--kind", "quantity", "--min", "0.0", "--max", "1.0"])
      |> generated("lib/my_app/types/probability.ex")
      |> assert_compiles(MyApp.Types.Probability)
    end

    test "an unbounded integer quantity" do
      gen(["MyApp.Types.Attempts", "--kind", "quantity", "--storage", "integer"])
      |> generated("lib/my_app/types/attempts.ex")
      |> assert_compiles(MyApp.Types.Attempts)
    end
  end

  describe "validation" do
    test "requires a kind" do
      assert_raise Mix.Error, ~r/--kind is required/, fn -> gen(["MyApp.Types.Script"]) end
    end

    test "rejects an unknown kind" do
      assert_raise Mix.Error, ~r/unknown --kind/, fn ->
        gen(["MyApp.Types.Script", "--kind", "colour"])
      end
    end

    test "rejects an unknown storage" do
      assert_raise Mix.Error, ~r/--storage must be/, fn ->
        gen(["MyApp.Types.X", "--kind", "quantity", "--storage", "bigint"])
      end
    end
  end
end
