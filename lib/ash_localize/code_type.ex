defmodule AshLocalize.CodeType do
  @moduledoc """
  Defines an `Ash.Type` for a code drawn from a controlled vocabulary.

  A *code* is a nominal value: an identifier that is either in CLDR's vocabulary or
  is not. `"AUD"`, `"Australia/Sydney"`, `"en-US"`, `"usca"`. Codes are not
  quantities — you cannot order or aggregate them, and comparing two is equality
  rather than magnitude. That is what separates them from `AshLocalize.QuantityType`
  (dimensionless numbers) and `AshLocalize.UnitType` (dimensioned numbers).

  Every code type does the same three things: store a string so it works on every
  data layer, reject values outside the vocabulary, and canonicalise what it accepts.
  Only the validation differs, so that is the only thing a type using this macro has
  to write.

  ## Defining one

      defmodule MyApp.Types.Script do
        use AshLocalize.CodeType, message: "is not a valid script"

        @impl true
        def cast_code(value, _constraints) do
          case Localize.validate_script(value) do
            {:ok, code} -> {:ok, to_string(code)}
            {:error, _reason} -> :error
          end
        end
      end

  Then register the short name and use it as any built-in:

      config :ash, :custom_types, script: MyApp.Types.Script

      attribute :writing_system, :script

  ## The callback

  `c:cast_code/2` receives a binary — `nil`, atoms and non-string input are handled
  before it is called — and returns `{:ok, canonical}` or `{:error, keyword}`.

  For the ordinary rejection, call the generated `code_error/0`, which produces the
  `:message` given to `use`. Return a keyword list directly when the reason is more
  useful than "invalid" — `AshLocalize.Types.Subdivision` reports the territory a
  code failed against.

  ## Options

    * `:message` (required) — the validation error for a rejected value.
    * `:constraints` — extra `Spark.Options` constraint definitions, if the type
      takes any. Defaults to `[]`.

  ## Atoms

  Codes are frequently written as atoms — `:AUD`, `:usca` — so an atom input is
  converted to a string before validation rather than rejected. Storage is always a
  string.
  """

  @doc """
  Validates and canonicalises a code. See the module documentation.
  """
  @callback cast_code(String.t(), constraints :: Keyword.t()) ::
              {:ok, String.t()} | {:error, Keyword.t()}

  defmacro __using__(opts) do
    quote bind_quoted: [
            message: Keyword.fetch!(opts, :message),
            extra_constraints: Keyword.get(opts, :constraints, [])
          ] do
      use Ash.Type

      @behaviour AshLocalize.CodeType

      @invalid_message message
      @constraints extra_constraints

      @impl Ash.Type
      def constraints, do: @constraints

      @impl Ash.Type
      def storage_type(_constraints), do: :string

      @impl Ash.Type
      def cast_input(nil, _constraints), do: {:ok, nil}

      def cast_input(value, constraints) when is_atom(value) do
        value |> Atom.to_string() |> cast_input(constraints)
      end

      def cast_input(value, constraints) when is_binary(value) do
        cast_code(value, constraints)
      end

      def cast_input(_value, _constraints), do: code_error()

      @doc false
      def code_error, do: {:error, message: @invalid_message}

      @impl Ash.Type
      def cast_stored(nil, _constraints), do: {:ok, nil}
      def cast_stored(value, _constraints) when is_binary(value), do: {:ok, value}
      def cast_stored(_value, _constraints), do: :error

      @impl Ash.Type
      def dump_to_native(nil, _constraints), do: {:ok, nil}
      def dump_to_native(value, _constraints) when is_binary(value), do: {:ok, value}
      def dump_to_native(_value, _constraints), do: :error

      defoverridable constraints: 0, storage_type: 1, cast_input: 2
    end
  end
end
