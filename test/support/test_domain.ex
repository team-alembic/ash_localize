defmodule AshLocalize.Test.Domain do
  @moduledoc false
  # Test-support domain hosting the resources that exercise ash_localize end to end.

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshLocalize.Test.Profile
  end
end
