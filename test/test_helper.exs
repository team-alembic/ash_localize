# The Ets data layer logs each write at :debug; keep test output to signal only.
Logger.configure(level: :warning)

ExUnit.start()
