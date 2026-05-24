if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshLocalize.Install do
    @example "mix igniter.install ash_localize"
    @moduledoc """
    Installs and configures `ash_localize`.

    Runs automatically as part of `mix igniter.install ash_localize`. Sets
    `config :ash_localize, default_locale: "en"` if no default is configured, and
    registers the scalar and unit-category types under `config :ash, :custom_types`.

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

    # Scalar + unit-category short names — always registered.
    @core_types [
      locale: AshLocalize.Types.Locale,
      territory: AshLocalize.Types.Territory,
      currency_code: AshLocalize.Types.CurrencyCode,
      count: AshLocalize.Types.Count,
      ordinal: AshLocalize.Types.Ordinal,
      percentage: AshLocalize.Types.Percentage,
      ratio: AshLocalize.Types.Ratio,
      score: AshLocalize.Types.Score,
      rating: AshLocalize.Types.Rating,
      unit: AshLocalize.Types.Unit,
      length: AshLocalize.Types.Length,
      distance: AshLocalize.Types.Distance,
      mass: AshLocalize.Types.Mass,
      speed: AshLocalize.Types.Speed,
      acceleration: AshLocalize.Types.Acceleration,
      force: AshLocalize.Types.Force,
      volume: AshLocalize.Types.Volume,
      area: AshLocalize.Types.Area,
      temperature: AshLocalize.Types.Temperature,
      energy: AshLocalize.Types.Energy,
      power: AshLocalize.Types.Power,
      pressure: AshLocalize.Types.Pressure,
      angle: AshLocalize.Types.Angle,
      frequency: AshLocalize.Types.Frequency,
      digital: AshLocalize.Types.Digital,
      electric_current: AshLocalize.Types.ElectricCurrent,
      voltage: AshLocalize.Types.Voltage
    ]

    # Satellite-gated types — registered when the optional dep is present.
    @satellite_types [
      {:localize_person_names, :person_name, AshLocalize.Types.PersonName},
      {:localize_phone_number, :phone_number, AshLocalize.Types.PhoneNumber},
      {:localize_address, :postal_address, AshLocalize.Types.PostalAddress}
    ]

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
