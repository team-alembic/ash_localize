defmodule Mix.Tasks.AshLocalize.Gen.UnitTypeTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "creates a category-less unit type module" do
    igniter =
      test_project()
      |> Igniter.compose_task("ash_localize.gen.unit_type", [
        "MyApp.Units.Jerk",
        "--base-unit",
        "meter-per-cubic-second"
      ])

    diff = diff(igniter)
    assert diff =~ "defmodule MyApp.Units.Jerk do"
    assert diff =~ ~s(use AshLocalize.UnitType, base_unit: "meter-per-cubic-second")
  end

  test "registers a short name when --short-name is given" do
    igniter =
      test_project()
      |> Igniter.compose_task("ash_localize.gen.unit_type", [
        "MyApp.Units.Jerk",
        "--base-unit",
        "meter-per-cubic-second",
        "--short-name",
        "jerk"
      ])

    diff = diff(igniter)
    assert diff =~ "jerk: MyApp.Units.Jerk"
  end

  test "passes --category through to the use line" do
    igniter =
      test_project()
      |> Igniter.compose_task("ash_localize.gen.unit_type", [
        "MyApp.Units.RoadDistance",
        "--base-unit",
        "kilometer",
        "--category",
        "length"
      ])

    diff = diff(igniter)
    assert diff =~ ~s(category: "length", base_unit: "kilometer")
  end
end
