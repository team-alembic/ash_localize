# The Ets data layer logs each write at :debug; keep test output to signal only.
Logger.configure(level: :warning)

# `:phone_number` and `:postal_address` need libphonenumber and libpostal, which
# are opt-in — see native_deps/0 in mix.exs. When ash_localize was compiled
# without them the types do not exist, so exclude their tests rather than fail on
# a missing module. ExUnit reports the exclusion, so a short run is visible
# rather than silent.
exclude =
  if Code.ensure_loaded?(Localize.PhoneNumber) and Code.ensure_loaded?(Localize.Address) do
    []
  else
    [:native]
  end

ExUnit.start(exclude: exclude)
