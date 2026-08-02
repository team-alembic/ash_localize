defmodule AshLocalize.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Ash Framework integration for Localize: CLDR-validated locale-aware types, formatting calculations, and translatable attributes for Ash resources."
  @source_url "https://github.com/elixir-localize/ash_localize"

  def project do
    # Resolved once here and exported, so mix.exs, config/config.exs and the test
    # support resource all agree without each re-running the detection.
    native = native?()
    System.put_env("ASH_LOCALIZE_NATIVE", if(native, do: "1", else: "0"))
    drop_stale_build(native)

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
      # The Igniter mix tasks call Mix.Task.run/2, Mix.raise/1 and friends. `:mix`
      # is not in the default PLT, so without this every one of them is reported
      # as an unknown function.
      dialyzer: [plt_add_apps: [:mix]],
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
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:doctor, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ] ++ native_deps()
  end

  # `localize_phone_number` and `localize_address` build NIFs against
  # libphonenumber and libpostal. Neither is on a stock CI runner and libpostal is
  # not packaged at all, so declaring them unconditionally means the project cannot
  # compile anywhere the system libraries are absent.
  #
  # So they follow the libraries: present on the machine, they are declared and the
  # full suite runs; absent, they are skipped. A developer working on this library
  # has them installed and gets everything without opting in, and a bare runner
  # still compiles.
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

  # ASH_LOCALIZE_NATIVE forces the answer either way. The native CI job sets 1 so
  # that a failed libpostal build fails the job, rather than silently dropping to
  # the reduced suite and reporting success.
  defp native? do
    case System.get_env("ASH_LOCALIZE_NATIVE") do
      truthy when truthy in ~w(1 true) ->
        true

      falsy when falsy in ~w(0 false) ->
        false

      _ ->
        lib?("libphonenumber", "phonenumbers/phonenumberutil.h") and
          lib?("libpostal", "postal/libpostal.h")
    end
  end

  # Mirrors what the NIF Makefiles do: pkg-config where the library ships a .pc
  # (libpostal does), a header search where it does not (libphonenumber).
  defp lib?(pkg, header) do
    pkg_config?(pkg) or header?(header)
  end

  defp pkg_config?(pkg) do
    match?({_, 0}, System.cmd("pkg-config", ["--exists", pkg], stderr_to_stdout: true))
  rescue
    ErlangError -> false
  end

  # The natives are gated at compile time, in this file, in config/config.exs and
  # in guards around the type modules themselves. Mix cannot see that an
  # environment variable or a newly installed library changed any of it, so it
  # reuses the other mode's build and fails with ":phone_number is not a valid
  # type" — which points nowhere near the cause. Track the mode and drop our own
  # build artefacts when it flips.
  defp drop_stale_build(native) do
    # Not Mix.Project.build_path/0: during project/0 the env is not settled, so it
    # reports _build/dev even under `mix test`. Sweep every env instead.
    marker = "_build/.ash_localize_native"
    current = to_string(native)

    if File.exists?(marker) and File.read!(marker) != current do
      Enum.each(Path.wildcard("_build/*/lib/ash_localize"), &File.rm_rf!/1)
    end

    File.mkdir_p!("_build")
    File.write!(marker, current)
  end

  defp header?(header) do
    ["/usr/include", "/usr/local/include", "/opt/homebrew/include"]
    |> Enum.any?(&File.exists?(Path.join(&1, header)))
  end

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
