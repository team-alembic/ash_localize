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

  use AshLocalize.CodeType, message: "is not a valid locale"

  @impl true
  def cast_code(value, _constraints) do
    with {:ok, tag} <- Localize.LanguageTag.parse(value),
         {:ok, canonical} <- Localize.LanguageTag.canonicalize(tag) do
      {:ok, Localize.LanguageTag.to_string(canonical)}
    else
      {:error, _reason} -> code_error()
    end
  end
end
