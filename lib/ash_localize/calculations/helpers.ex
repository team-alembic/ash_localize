defmodule AshLocalize.Calculations.Helpers do
  @moduledoc false
  # Shared plumbing for the locale-aware formatting calculations: option
  # validation, and the resolve-locale-once-then-map-records loop.

  alias AshLocalize.Context

  @doc """
  Validates that an `:field` option naming an atom attribute is present.

  Returns `{:ok, opts}` or `{:error, reason}`, the contract of a calculation's
  `init/1` callback.
  """
  @spec require_field(keyword()) :: {:ok, keyword()} | {:error, String.t()}
  def require_field(opts) do
    case opts[:field] do
      field when is_atom(field) and not is_nil(field) ->
        {:ok, opts}

      _other ->
        {:error, "a `:field` option (an atom naming the source attribute) is required"}
    end
  end

  @doc """
  Resolves the locale once, then maps each record through `formatter`.

  `formatter` is `(value, locale, record -> term)` and is invoked only for records
  whose `:field` value is non-`nil`; a `nil` value yields a `nil` result without
  calling `formatter`. Returns the list of results, or `{:error, reason}` if no locale
  can be resolved.
  """
  @spec format([map()], keyword(), map(), (term(), term(), map() -> term())) ::
          [term()] | {:error, String.t()}
  def format(records, opts, context, formatter) when is_function(formatter, 3) do
    case Context.from_calculation(context, actor_locale: opts[:actor_locale]) do
      {:ok, locale} ->
        Enum.map(records, &format_record(&1, opts[:field], locale, formatter))

      {:error, :no_locale} ->
        {:error, "AshLocalize formatting calculation could not resolve a locale"}
    end
  end

  defp format_record(record, field, locale, formatter) do
    case Map.get(record, field) do
      nil -> nil
      value -> formatter.(value, locale, record)
    end
  end
end
