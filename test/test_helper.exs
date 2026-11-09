# The Ets data layer logs each write at :debug; keep test output to signal only.
Logger.configure(level: :warning)

# `:phone_number` and `:postal_address` need libphonenumber and libpostal. When
# those are absent the types are not compiled and neither are their tests — see
# native_deps/0 in mix.exs — so say so rather than quietly reporting a short run.
unless Code.ensure_loaded?(Localize.PhoneNumber) and Code.ensure_loaded?(Localize.Address) do
  IO.puts(:stderr, """
  \n\e[33mlibphonenumber/libpostal absent: :phone_number and :postal_address tests \
  are not being run. Install both, or set ASH_LOCALIZE_NATIVE=1 to fail instead \
  of skip.\e[0m
  """)
end

# Elixir ships a UTC-only database; time zone labels need real offsets.
Calendar.put_time_zone_database(Tz.TimeZoneDatabase)

ExUnit.start()
