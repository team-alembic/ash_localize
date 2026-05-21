defmodule AshLocalize.Test.ActorLocale do
  @moduledoc false
  # Test helper: an actor-locale extractor used to exercise the `:actor_locale`
  # option of `AshLocalize.Context.locale/2` in its `{module, function}` form.

  def from_actor(%{lang: lang}), do: lang
  def from_actor(_actor), do: nil
end
