defmodule AshLocalize.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Ash Framework integration for Localize: CLDR-validated locale-aware types, formatting calculations, and translatable attributes for Ash resources."
  @source_url "https://github.com/elixir-localize/ash_localize"

  def project do
    [
      app: :ash_localize,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      package: package(),
      docs: docs(),
      description: @description,
      source_url: @source_url,
      homepage_url: @source_url,
      name: "AshLocalize"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [test: ["localize.download_locales", "test"]]
  end

  defp deps do
    [
      {:ash, "~> 3.5"},
      {:localize, "~> 1.0"},
      {:localize_person_names, "~> 1.0", optional: true},
      {:ash_money, "~> 0.2.6", optional: true},
      {:igniter, "~> 0.8", optional: true},
      {:ex_doc, "~> 0.34", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ] ++ native_deps()
  end

  # `localize_phone_number` and `localize_address` build NIFs against
  # libphonenumber and libpostal. Neither is on a stock runner and libpostal is
  # not packaged at all, so declaring them unconditionally means the project
  # cannot compile anywhere the system libraries are absent.
  #
  # They are opt-in instead. `ASH_LOCALIZE_NATIVE=1 mix test` runs the full suite
  # once the libraries are installed; without it those two types are absent, which
  # is exactly the state a consumer who has not added the packages is in — the
  # types are `Code.ensure_loaded?` guarded either way, so nothing else changes.
  defp native_deps do
    if native?() do
      [
        {:localize_phone_number, "~> 1.0", optional: true},
        {:localize_address, "~> 1.0", optional: true}
      ]
    else
      []
    end
  end

  defp native?, do: System.get_env("ASH_LOCALIZE_NATIVE") in ~w(1 true)

  defp package do
    [
      name: "ash_localize",
      licenses: ["Apache-2.0"],
      files:
        ~w(lib priv/messages documentation .formatter.exs mix.exs README* LICENSE* CHANGELOG* usage-rules.md),
      links: %{
        "GitHub" => @source_url,
        "Localize" => "https://github.com/elixir-localize/localize"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "usage-rules.md",
        "documentation/custom_types.md",
        "documentation/custom_units.md",
        "CHANGELOG.md"
      ]
    ]
  end
end
