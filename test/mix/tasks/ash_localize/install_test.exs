defmodule Mix.Tasks.AshLocalize.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  alias Igniter.Project.Deps

  test "configures default_locale and registers the core type short names" do
    igniter = test_project() |> Igniter.compose_task("ash_localize.install", [])

    diff = diff(igniter)

    assert diff =~ ~s(default_locale: "en")

    for module <- ~w(Locale Territory Timezone CurrencyCode Count Percentage Ratio Unit) do
      assert diff =~ "AshLocalize.Types.#{module}"
    end

    # Satellite-gated types are not registered when their optional dep is absent.
    refute diff =~ "AshLocalize.Types.PostalAddress"
    refute diff =~ "AshLocalize.Types.PhoneNumber"
  end

  test "leaves the domain-specific types for the consumer to register" do
    igniter = test_project() |> Igniter.compose_task("ash_localize.install", [])

    diff = diff(igniter)

    # The unit categories and the narrower numeric types are real but opinionated
    # choices, so the installer names them in a notice rather than writing them in.
    for module <- ~w(Subdivision Ordinal Score Rating Speed Mass Length Temperature) do
      refute diff =~ "AshLocalize.Types.#{module}"
    end

    assert [notice] = igniter.notices
    assert notice =~ ":subdivision"
    assert notice =~ ":mass"
  end

  test "registers satellite types when their optional dep is present" do
    igniter =
      test_project()
      |> Deps.add_dep({:localize_address, "~> 1.0"})
      |> Igniter.compose_task("ash_localize.install", [])

    diff = diff(igniter)

    assert diff =~ "AshLocalize.Types.PostalAddress"
    refute diff =~ "AshLocalize.Types.PhoneNumber"
  end
end
