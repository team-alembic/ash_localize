defmodule AshLocalizeTest do
  # async: false — exercises the global :ash_localize application environment.
  use ExUnit.Case, async: false

  describe "default_locale/0" do
    test "returns the configured default locale" do
      assert AshLocalize.default_locale() == "en"
    end

    test "returns nil when no default locale is configured" do
      original = Application.get_env(:ash_localize, :default_locale)
      Application.delete_env(:ash_localize, :default_locale)
      on_exit(fn -> Application.put_env(:ash_localize, :default_locale, original) end)

      assert AshLocalize.default_locale() == nil
    end
  end
end
