defmodule AshLocalize.Types.Locale do
  @moduledoc """
  An `Ash.Type` for a CLDR-validated [BCP 47](https://www.rfc-editor.org/info/bcp47)
  locale identifier.

  Stored as a string, so it works on every Ash data layer. Casting parses the value
  with Localize, rejects anything CLDR does not recognise — both malformed strings and
  grammatically valid but unknown subtags — and stores the canonical form: `"en-us"`
  becomes `"en-US"`, `"EN"` becomes `"en"`.

  Casting applies canonical *syntax* (case, variant and extension ordering) but not
  likely-subtag minimisation, so `"zh-TW"` is preserved rather than rewritten.

  Referenced as `:locale` once the short type names are registered — see the README.
  """

  use Ash.Type

  @impl true
  def storage_type(_constraints), do: :string

  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}

  def cast_input(value, _constraints) when is_binary(value) do
    with {:ok, tag} <- Localize.LanguageTag.parse(value),
         {:ok, canonical} <- Localize.LanguageTag.canonicalize(tag) do
      {:ok, Localize.LanguageTag.to_string(canonical)}
    else
      {:error, _reason} -> {:error, message: "is not a valid locale"}
    end
  end

  def cast_input(_value, _constraints), do: {:error, message: "is not a valid locale"}

  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}
  def cast_stored(value, _constraints) when is_binary(value), do: {:ok, value}
  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}
  def dump_to_native(value, _constraints) when is_binary(value), do: {:ok, value}
  def dump_to_native(_value, _constraints), do: :error
end
