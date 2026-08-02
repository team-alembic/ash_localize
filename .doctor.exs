%Doctor.Config{
  ignore_modules: [
    # Mix tasks are entry points whose public surface is `run/1` — a behaviour
    # callback, not something a @spec adds anything to.
    ~r/^Mix\.Tasks\./,
    # The three type-defining macros. Doctor counts the functions generated inside
    # their `quote` blocks as undocumented functions of the macro module, and a
    # @doc cannot be attached to those. All three carry full moduledocs.
    AshLocalize.CodeType,
    AshLocalize.QuantityType,
    AshLocalize.UnitType
  ],
  ignore_paths: [],
  # Per-module spec coverage is not a useful gate here: the type modules are
  # almost entirely `@impl Ash.Type` callbacks, whose contracts come from the
  # behaviour. The overall floor below is what actually holds the line.
  min_module_spec_coverage: 0,
  min_module_doc_coverage: 40,
  min_overall_doc_coverage: 80,
  min_overall_spec_coverage: 70,
  min_overall_moduledoc_coverage: 100,
  exception_moduledoc_required: true,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: false
}
