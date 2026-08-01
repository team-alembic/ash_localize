if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshLocalize.Gen.Type do
    @example "mix ash_localize.gen.type MyApp.Types.Script --kind code \\\n  --validator Localize.validate_script --short-name script"
    @moduledoc """
    Generates a custom AshLocalize type.

    `ash_localize` groups its types by what the value *is*, and each group has a
    macro that supplies everything except the part that differs:

      * `code` — a value from a controlled vocabulary (`"AUD"`, `"en-US"`,
        `"Australia/Sydney"`). Nominal: it cannot be ordered or aggregated, and
        comparing two is equality. Built on `AshLocalize.CodeType`; you supply the
        validation.

      * `quantity` — a dimensionless magnitude that carries meaning (a count, a
        rank, a percentage). Built on `AshLocalize.QuantityType`; you supply the
        storage and the bounds.

    For a *dimensioned* quantity — a length, a mass, anything with a unit — use
    `mix ash_localize.gen.unit_type` instead. Its options are genuinely different
    (a base unit and an optional CLDR category), and the unit is what makes it a
    different kind of thing.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    - `--kind` (required) — `code` or `quantity`.
    - `--short-name`, `-s` — register the type under this atom in
      `config :ash, :custom_types`, so resources can write `attribute :foo, :short_name`.
    - `--message` — the validation error for a rejected value. Defaults to
      `"is not a valid <type>"` for a code, `"is not a number"` for a quantity.

    ### `--kind code`

    - `--validator` — the Localize function to validate through, e.g.
      `Localize.validate_script`. Called with the value and expected to return
      `{:ok, code} | {:error, reason}`. Omit it to generate a `TODO` body.

    ### `--kind quantity`

    - `--storage` — `decimal` (default) or `integer`.
    - `--min`, `--max` — default bounds. Omit for unbounded.
    """
    @shortdoc "Generates a custom AshLocalize code or quantity type"

    use Igniter.Mix.Task

    alias Igniter.Project.Config
    alias Igniter.Project.Module, as: ProjectModule

    @kinds ~w(code quantity)

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        schema: [
          kind: :string,
          short_name: :string,
          message: :string,
          validator: :string,
          storage: :string,
          min: :string,
          max: :string
        ],
        example: @example,
        positional: [:module_name],
        aliases: [s: :short_name, k: :kind]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      opts = igniter.args.options
      kind = opts[:kind] || Mix.raise("--kind is required (one of: #{Enum.join(@kinds, ", ")})")

      unless kind in @kinds do
        Mix.raise("unknown --kind #{inspect(kind)} (one of: #{Enum.join(@kinds, ", ")})")
      end

      module = ProjectModule.parse(igniter.args.positional.module_name)
      file = ProjectModule.proper_location(igniter, module)

      igniter
      |> Igniter.create_new_file(file, contents(kind, module, opts))
      |> register_short_name(opts[:short_name], module)
    end

    defp contents("code", module, opts) do
      name = readable_name(module)
      message = opts[:message] || "is not a valid #{name}"

      """
      defmodule #{inspect(module)} do
        @moduledoc \"\"\"
        An `Ash.Type` for a #{name} code, validated through Localize.

        Stored as a string, so it works on every Ash data layer.
        \"\"\"

        use AshLocalize.CodeType, message: "#{message}"

        @impl true
        def cast_code(value, _constraints) do
      #{cast_code_body(opts[:validator])}
        end
      end
      """
    end

    defp contents("quantity", module, opts) do
      name = readable_name(module)
      storage = opts[:storage] || "decimal"

      unless storage in ~w(decimal integer) do
        Mix.raise("--storage must be decimal or integer, got #{inspect(storage)}")
      end

      declared =
        [
          "storage: :#{storage}",
          ~s(message: "#{opts[:message] || "is not a number"}")
        ] ++
          Enum.reject([bound("min", opts[:min]), bound("max", opts[:max])], &is_nil/1)

      """
      defmodule #{inspect(module)} do
        @moduledoc \"\"\"
        An `Ash.Type` for a #{name} — a dimensionless quantity stored as
        a#{if storage == "integer", do: "n", else: ""} `#{storage}`.
        \"\"\"

        use AshLocalize.QuantityType,
          #{Enum.join(declared, ",\n    ")}
      end
      """
    end

    defp bound(_key, nil), do: nil
    defp bound(key, value), do: "#{key}: #{value}"

    defp cast_code_body(nil) do
      """
          # TODO: validate `value` against the vocabulary this type belongs to, and
          # return the canonical form. Return `code_error()` to reject it.
          {:ok, value}\
      """
    end

    defp cast_code_body(validator) do
      """
          case #{validator}(value) do
            {:ok, code} -> {:ok, to_string(code)}
            {:error, _reason} -> code_error()
          end\
      """
    end

    defp readable_name(module) do
      module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.replace("_", " ")
    end

    defp register_short_name(igniter, nil, _module), do: igniter

    defp register_short_name(igniter, short_name, module) do
      Config.configure(
        igniter,
        "config.exs",
        :ash,
        [:custom_types, String.to_atom(short_name)],
        module
      )
    end
  end
else
  defmodule Mix.Tasks.AshLocalize.Gen.Type do
    @shortdoc "Generates a custom AshLocalize code or quantity type"
    @moduledoc "Requires `igniter`."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task `ash_localize.gen.type` requires `igniter` to be installed.

      Add `{:igniter, "~> 0.8", only: [:dev]}` to your `mix.exs` deps, run
      `mix deps.get`, then try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
