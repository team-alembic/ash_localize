defmodule AshLocalize.ErrorMessage.Catalogue.Builtin do
  @moduledoc """
  The catalogue `ash_localize` ships, read from `priv/messages/ash/<locale>.exs`.

  Each file evaluates to a map of Ash msgid to MF2 message. They are read at compile
  time and embedded, so lookup is a function clause and costs nothing at runtime.

  A locale falls back along its subtags — `"de-AT"` tries `de-AT` then `de` — so a
  regional locale inherits its language's translations rather than dropping straight
  to English.

  > #### Seed, not a complete catalogue {: .warning}
  >
  > The shipped files cover a first tranche and are pending translator review. An
  > untranslated msgid is not an error: it falls back to the English string with
  > locale-correct interpolated values, which is still an improvement on Ash's
  > current rendering.
  """

  @behaviour AshLocalize.ErrorMessage.Catalogue

  messages_dir = Path.join([__DIR__, "..", "..", "..", "..", "priv", "messages", "ash"])

  catalogues =
    case File.ls(messages_dir) do
      {:ok, files} ->
        for file <- Enum.sort(files), Path.extname(file) == ".exs" do
          path = Path.join(messages_dir, file)
          {messages, _bindings} = Code.eval_file(path)
          {Path.basename(file, ".exs"), messages, path}
        end

      {:error, _reason} ->
        []
    end

  for {_locale, _messages, path} <- catalogues do
    @external_resource path
  end

  @impl true
  def fetch(msgid, locale) when is_binary(msgid) and is_binary(locale) do
    locale |> candidates() |> do_fetch(msgid)
  end

  def fetch(msgid, locale) when is_binary(msgid), do: fetch(msgid, to_string(locale))

  defp do_fetch([], _msgid), do: :error

  defp do_fetch([locale | rest], msgid) do
    case lookup(locale, msgid) do
      {:ok, message} -> {:ok, message}
      :error -> do_fetch(rest, msgid)
    end
  end

  # `"de-AT"` -> ["de-AT", "de"]. Most specific first.
  defp candidates(locale) do
    locale
    |> String.split("-")
    |> Enum.scan(&"#{&2}-#{&1}")
    |> Enum.reverse()
  end

  for {locale, messages, _path} <- catalogues do
    for {msgid, message} <- messages do
      defp lookup(unquote(locale), unquote(msgid)), do: {:ok, unquote(message)}
    end
  end

  defp lookup(_locale, _msgid), do: :error

  @doc """
  Returns the locales the shipped catalogue has any translations for.
  """
  @spec known_locales() :: [String.t()]
  def known_locales, do: unquote(Enum.map(catalogues, fn {locale, _, _} -> locale end))
end
