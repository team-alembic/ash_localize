if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshLocalize.Install do
    @example "mix igniter.install ash_localize"
    @moduledoc """
    Installs and configures `ash_localize`.

    Runs automatically as part of `mix igniter.install ash_localize`. Sets
    `config :ash_localize, default_locale: "en"` if no default is configured, and
    registers a starting set of type short names under `config :ash, :custom_types`:
    `:locale`, `:territory`, `:timezone`, `:currency_code`, `:count`, `:percentage`,
    `:ratio` and `:unit`.

    That is deliberately a subset. The package ships around thirty short names, and
    the unit categories in particular are domain-specific — a logistics application
    wants `:mass` and `:volume`, a telemetry one wants `:acceleration` and
    `:frequency`, and neither wants the other's. Registering all of them would bury
    the handful a project references under two dozen it never will, so the installer
    prints the remainder as a notice and leaves the choice to the consumer.

    If the consumer's project also declares any of the optional satellite packages
    (`localize_person_names`, `localize_phone_number`, `localize_address`), the
    corresponding type short names (`:person_name`, `:phone_number`, `:postal_address`)
    are registered as well.

    ## Example

    ```bash
    #{@example}
    ```
    """
    @shortdoc "Installs and configures ash_localize"

    use Igniter.Mix.Task

    alias Igniter.Project.Config
    alias Igniter.Project.Deps

    # A starting set, not a catalogue. `ash_localize` ships around thirty short
    # names; writing all of them into a consumer's config buries the handful they
    # will actually reference under two dozen they never will — and the unit
    # categories in particular are domain-specific, so no single set is right.
    # These are the ones a localized application reaches for regardless of domain,
    # plus the generic `:unit` as the entry point to the units story. The notice
    # below points at the rest.
    @core_types [
      locale: AshLocalize.Types.Locale,
      territory: AshLocalize.Types.Territory,
      timezone: AshLocalize.Types.Timezone,
      currency_code: AshLocalize.Types.CurrencyCode,
      count: AshLocalize.Types.Count,
      percentage: AshLocalize.Types.Percentage,
      ratio: AshLocalize.Types.Ratio,
      unit: AshLocalize.Types.Unit
    ]

    # Satellite-gated types — registered when the optional dep is present.
    @satellite_types [
      {:localize_person_names, :person_name, AshLocalize.Types.PersonName},
      {:localize_phone_number, :phone_number, AshLocalize.Types.PhoneNumber},
      {:localize_address, :postal_address, AshLocalize.Types.PostalAddress}
    ]

    @notice """
    ash_localize registered a starting set of type short names under
    `config :ash, :custom_types`. The package ships more — register the ones you
    use and leave the rest out:

      :subdivision, :ordinal, :score, :rating

      unit categories — :length, :distance, :mass, :speed, :acceleration, :force,
      :volume, :area, :temperature, :energy, :power, :pressure, :angle,
      :frequency, :digital, :electric_current, :voltage

    A unit category is a `:unit` pre-bound to a base unit, so `:mass` is worth
    registering over the generic `:unit` wherever the dimension is fixed.
    """

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{schema: [], example: @example}
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Config.configure_new(
        "config.exs",
        :ash_localize,
        [:default_locale],
        "en"
      )
      |> register_types(@core_types)
      |> add_satellite_types()
      |> Igniter.add_notice(@notice)
    end

    defp register_types(igniter, types) do
      Enum.reduce(types, igniter, fn {short_name, module}, igniter ->
        Config.configure(igniter, "config.exs", :ash, [:custom_types, short_name], module)
      end)
    end

    defp add_satellite_types(igniter) do
      satellites =
        for {dep, short_name, module} <- @satellite_types,
            Deps.has_dep?(igniter, dep) do
          {short_name, module}
        end

      register_types(igniter, satellites)
    end
  end
else
  defmodule Mix.Tasks.AshLocalize.Install do
    @shortdoc "Installs and configures ash_localize"
    @moduledoc "Requires `igniter`."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task `ash_localize.install` requires `igniter` to be installed.

      Add `{:igniter, "~> 0.8", only: [:dev]}` to your `mix.exs` deps, run
      `mix deps.get`, then try again.

      See https://hexdocs.pm/igniter for more.
      """)

      exit({:shutdown, 1})
    end
  end
end
