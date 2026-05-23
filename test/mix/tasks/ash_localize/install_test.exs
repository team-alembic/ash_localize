defmodule Mix.Tasks.AshLocalize.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  alias Igniter.Project.Deps

  test "configures default_locale and registers the core type short names" do
    igniter = test_project() |> Igniter.compose_task("ash_localize.install", [])

    diff = diff(igniter)

    assert diff =~ ~s(default_locale: "en")
    assert diff =~ "AshLocalize.Types.Locale"
    assert diff =~ "AshLocalize.Types.Speed"
    # Satellite-gated types are not registered when their optional dep is absent.
    refute diff =~ "AshLocalize.Types.PostalAddress"
    refute diff =~ "AshLocalize.Types.PhoneNumber"
  end

  test "registers satellite types when their optional dep is present" do
    igniter =
      test_project()
      |> Deps.add_dep({:localize_address, "~> 0.2"})
      |> Igniter.compose_task("ash_localize.install", [])

    diff = diff(igniter)

    assert diff =~ "AshLocalize.Types.PostalAddress"
    refute diff =~ "AshLocalize.Types.PhoneNumber"
  end
end
