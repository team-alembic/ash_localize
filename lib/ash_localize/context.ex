defmodule AshLocalize.Context do
  @moduledoc """
  Resolves the active locale from one deterministic chain.

  Every calculation, validation, change, and store adapter that needs a locale resolves
  it here, so the answer is the same regardless of who is asking.

  ## Resolution chain

  Most specific to least, the first non-`nil` arm wins:

  1. **Explicit argument** — the `:argument` option. An action or calculation that
     declares a `locale` argument passes its value here; a deliberate choice always wins.
  2. **Ash context** — the `:locale` key of the supplied context map, set per-operation
     via `Ash.Query`/`Ash.Changeset` context or `Ash.set_context/2` upstream.
  3. **Actor-derived** — off by default. Opt in with the `:actor_locale` option, a
     one-arity function (or `{module, function}`) applied to the context's `:actor`.
  4. **Application default** — `AshLocalize.default_locale/0`.

  The process dictionary (`Localize.put_locale/1`) and the tenant are deliberately
  excluded; see `docs/PLAN.md` for the rationale. Code that wants process-dictionary or
  tenant behaviour copies the locale into the Ash context upstream of the operation.

  ## Examples

      iex> AshLocalize.Context.locale(%{locale: "ja-JP"}, [])
      {:ok, "ja-JP"}

      iex> AshLocalize.Context.locale(%{}, argument: "fr")
      {:ok, "fr"}

      iex> AshLocalize.Context.locale!(%{}, [])
      "en"
  """

  @typedoc """
  The context map `locale/2` reads. It may carry a `:locale` key (arm 2) and an
  `:actor` key (arm 3); any other keys are ignored.
  """
  @type context :: %{
          optional(:locale) => term(),
          optional(:actor) => term(),
          optional(any()) => any()
        }

  @typedoc "An actor-locale extractor: a one-arity function or a `{module, function}` pair."
  @type actor_locale :: (term() -> term() | nil) | {module(), atom()}

  @type option :: {:argument, term()} | {:actor_locale, actor_locale()}

  @doc """
  Resolves the active locale, returning `{:ok, locale}` or `{:error, :no_locale}`.

  See the module documentation for the resolution chain. `{:error, :no_locale}` is
  returned only when no arm resolves — in practice, when `:ash_localize` has no
  configured `default_locale`.
  """
  @spec locale(context(), [option()]) :: {:ok, term()} | {:error, :no_locale}
  def locale(context, opts \\ []) when is_map(context) and is_list(opts) do
    resolved =
      from_argument(opts) ||
        from_context(context) ||
        from_actor(context, opts) ||
        AshLocalize.default_locale()

    case resolved do
      nil -> {:error, :no_locale}
      locale -> {:ok, locale}
    end
  end

  @doc """
  Resolves the active locale, raising when none can be resolved.

  The raising variant of `locale/2`. Use it where a missing locale is a programmer
  error rather than a recoverable condition.
  """
  @spec locale!(context(), [option()]) :: term()
  def locale!(context, opts \\ []) do
    case locale(context, opts) do
      {:ok, locale} ->
        locale

      {:error, :no_locale} ->
        raise """
        AshLocalize could not resolve a locale.

        No explicit argument, context locale, or actor locale was supplied, and no
        application default is configured. Set one:

            config :ash_localize, default_locale: "en"
        """
    end
  end

  @doc """
  Resolves the active locale from an `Ash.Resource.Calculation` context.

  A convenience wrapper over `locale/2` for formatting calculations. It reads the
  `:locale` calculation argument (arm 1), the calculation's `source_context` (arm 2),
  and its `actor` (arm 3) from the supplied calculation context, then resolves exactly
  as `locale/2` does. `opts` accepts `:actor_locale`, as for `locale/2`.
  """
  @spec from_calculation(map(), [option()]) :: {:ok, term()} | {:error, :no_locale}
  def from_calculation(calculation_context, opts \\ []) when is_map(calculation_context) do
    arguments = Map.get(calculation_context, :arguments) || %{}
    source_context = Map.get(calculation_context, :source_context) || %{}
    actor = Map.get(calculation_context, :actor)

    source_context
    |> Map.put(:actor, actor)
    |> locale(Keyword.put_new(opts, :argument, Map.get(arguments, :locale)))
  end

  defp from_argument(opts), do: opts[:argument]

  defp from_context(context), do: Map.get(context, :locale)

  defp from_actor(context, opts) do
    with extractor when not is_nil(extractor) <- opts[:actor_locale],
         actor when not is_nil(actor) <- Map.get(context, :actor) do
      apply_extractor(extractor, actor)
    else
      _ -> nil
    end
  end

  defp apply_extractor(fun, actor) when is_function(fun, 1), do: fun.(actor)
  defp apply_extractor({module, function}, actor), do: apply(module, function, [actor])
end
