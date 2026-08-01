# `Localize.Chars` is the upstream polymorphic-formatting protocol — it already
# covers `Integer`, `Float`, `Decimal`, `Date`, `Time`, `NaiveDateTime`,
# `DateTime`, `Range`, `BitString`, `List`, `Localize.Unit`, `Localize.Duration`,
# `Localize.LanguageTag`, `Localize.Currency`. The satellite packages
# (`localize_address`, `localize_person_names`, `localize_phone_number`) ship
# their own `Localize.Chars` implementations for their value structs.
#
# That leaves one gap: `%Money{}` from `ex_money`. It's a non-Localize struct so
# upstream doesn't ship a `Localize.Chars` impl for it, but the protocol is
# meant to be extended exactly this way. The impl below pulls the currency from
# the value itself — coupled amount + currency is the whole point of using
# Money — and routes through `Localize.Number.to_string/2` to produce the
# locale-aware result.
#
# Wrapped in `Code.ensure_loaded?(Money)` so it vanishes when the consumer has
# neither `ex_money` nor `ash_money` in their deps. `Money` here is the
# `ex_money` struct, not the Ash type — `AshMoney.Types.Money` loads attribute
# values as `%Money{}`, so this impl covers both direct ex_money users and
# AshMoney consumers.

if Code.ensure_loaded?(Money) do
  defimpl Localize.Chars, for: Money do
    @moduledoc false

    def to_string(money), do: to_string(money, [])

    def to_string(money, options) do
      Localize.Number.to_string(
        Money.to_decimal(money),
        Keyword.put(options, :currency, Money.to_currency_code(money))
      )
    end
  end
end
