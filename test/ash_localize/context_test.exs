defmodule AshLocalize.ContextTest do
  # async: false — the "no default" cases mutate the application environment.
  use ExUnit.Case, async: false

  alias AshLocalize.Context
  alias AshLocalize.Test.ActorLocale

  doctest AshLocalize.Context

  describe "locale/2 resolution chain" do
    test "the explicit :argument option wins over every other arm" do
      assert Context.locale(%{locale: "fr", actor: %{lang: "es"}},
               argument: "ja-JP",
               actor_locale: {ActorLocale, :from_actor}
             ) == {:ok, "ja-JP"}
    end

    test "the context :locale key wins over the actor and the default" do
      assert Context.locale(%{locale: "fr", actor: %{lang: "es"}},
               actor_locale: {ActorLocale, :from_actor}
             ) == {:ok, "fr"}
    end

    test "the actor-derived locale is used when :actor_locale is given" do
      assert Context.locale(%{actor: %{lang: "es"}}, actor_locale: {ActorLocale, :from_actor}) ==
               {:ok, "es"}
    end

    test ":actor_locale also accepts a one-arity function" do
      assert Context.locale(%{actor: %{lang: "es"}}, actor_locale: & &1.lang) == {:ok, "es"}
    end

    test "the actor is ignored when :actor_locale is not supplied" do
      assert Context.locale(%{actor: %{lang: "es"}}, []) == {:ok, "en"}
    end

    test "an actor extractor that returns nil falls through to the default" do
      assert Context.locale(%{actor: %{name: "no lang"}},
               actor_locale: {ActorLocale, :from_actor}
             ) ==
               {:ok, "en"}
    end

    test "falls back to the application default locale" do
      assert Context.locale(%{}, []) == {:ok, "en"}
    end

    test "returns {:error, :no_locale} when nothing resolves and no default is configured" do
      without_default_locale(fn ->
        assert Context.locale(%{}, []) == {:error, :no_locale}
      end)
    end
  end

  describe "locale!/2" do
    test "returns the resolved locale string" do
      assert Context.locale!(%{locale: "fr"}, []) == "fr"
    end

    test "raises a clear error when no locale can be resolved" do
      without_default_locale(fn ->
        assert_raise RuntimeError, ~r/default_locale/, fn ->
          Context.locale!(%{}, [])
        end
      end)
    end
  end

  defp without_default_locale(fun) do
    original = Application.get_env(:ash_localize, :default_locale)
    Application.delete_env(:ash_localize, :default_locale)

    try do
      fun.()
    after
      Application.put_env(:ash_localize, :default_locale, original)
    end
  end
end
