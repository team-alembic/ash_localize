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

  defp deps do
    [
      {:ash, "~> 3.5"},
      {:localize, "~> 0.37"},
      {:localize_person_names, "~> 0.1", optional: true},
      {:localize_address, "~> 0.2", optional: true},
      {:localize_phone_number, github: "elixir-localize/localize_phonenumber", optional: true},
      # AshMoney brings ex_money transitively; our `Localize.Chars` impl for
      # `%Money{}` compiles whenever the Money struct is loadable. Pointed at
      # main while ash_money's Hex release still pins ex_money 5.x; switch to
      # `~> 0.3` once ash_money releases with ex_money 6 / Decimal 3 support.
      {:ash_money, github: "ash-project/ash_money", optional: true},
      {:igniter, "~> 0.8", optional: true},
      {:ex_doc, "~> 0.34", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      name: "ash_localize",
      licenses: ["Apache-2.0"],
      files: ~w(lib documentation .formatter.exs mix.exs README* LICENSE* CHANGELOG* usage-rules.md),
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
      extras: ["README.md", "usage-rules.md", "documentation/custom_units.md", "CHANGELOG.md"]
    ]
  end
end
