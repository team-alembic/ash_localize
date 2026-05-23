if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshLocalize.Gen.UnitType do
    @example ~S(mix ash_localize.gen.unit_type MyApp.Units.Jerk \
  --base-unit meter-per-cubic-second --short-name jerk)
    @moduledoc """
    Generates a custom AshLocalize unit type via `AshLocalize.UnitType`.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    - `--base-unit` (required) — CLDR unit identifier (the default `base_unit` for
      the generated type, e.g. `meter-per-cubic-second`).
    - `--category` — optional CLDR unit category (`"speed"`, `"length"`, …). Omit it
      for compound units CLDR does not categorise, like *jerk*.
    - `--short-name`, `-s` — register the type under this atom in
      `config :ash, :custom_types`, so resources can write `attribute :foo, :short_name`.
    """
    @shortdoc "Generates a custom AshLocalize unit type"

    use Igniter.Mix.Task

    alias Igniter.Project.Config
    alias Igniter.Project.Module, as: ProjectModule

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        schema: [
          base_unit: :string,
          category: :string,
          short_name: :string
        ],
        example: @example,
        positional: [:module_name],
        aliases: [s: :short_name]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      module_name = igniter.args.positional.module_name
      opts = igniter.args.options

      base_unit = opts[:base_unit] || Mix.raise("--base-unit is required")
      category = opts[:category]
      short_name = if opts[:short_name], do: String.to_atom(opts[:short_name])

      module = ProjectModule.parse(module_name)
      file = ProjectModule.proper_location(igniter, module)

      use_opts =
        if category,
          do: ~s(category: "#{category}", base_unit: "#{base_unit}"),
          else: ~s(base_unit: "#{base_unit}")

      igniter
      |> Igniter.create_new_file(file, """
      defmodule #{inspect(module)} do
        use AshLocalize.UnitType, #{use_opts}
      end
      """)
      |> register_short_name(short_name, module)
    end

    defp register_short_name(igniter, nil, _module), do: igniter

    defp register_short_name(igniter, short_name, module) do
      Config.configure(igniter, "config.exs", :ash, [:custom_types, short_name], module)
    end
  end
else
  defmodule Mix.Tasks.AshLocalize.Gen.UnitType do
    @shortdoc "Generates a custom AshLocalize unit type"
    @moduledoc "Requires `igniter`."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task `ash_localize.gen.unit_type` requires `igniter` to be installed.

      Add `{:igniter, "~> 0.8", only: [:dev]}` to your `mix.exs` deps, run
      `mix deps.get`, then try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
