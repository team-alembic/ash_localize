defmodule AshLocalize.Validations.ValidTerritory do
  @moduledoc """
  Validates that a string attribute holds a CLDR-recognised territory (region) code.

  Use this when you want to keep an attribute as a plain `:string` but still reject
  values Localize does not recognise. When you want validation *and* a typed,
  canonicalised value, use the `AshLocalize.Types.Territory` type instead.

      validations do
        validate {AshLocalize.Validations.ValidTerritory, attribute: :country}
      end

  ## Options

    * `:attribute` (required) — the atom name of the attribute to validate.

  A `nil` value passes; pair this with `allow_nil?: false` on the attribute if the
  value is required. The validation runs against CLDR data and so cannot be applied
  atomically.
  """

  use Ash.Resource.Validation

  alias AshLocalize.Types.Territory

  @impl true
  def init(opts) do
    case opts[:attribute] do
      attribute when is_atom(attribute) and not is_nil(attribute) ->
        {:ok, opts}

      _other ->
        {:error, "#{inspect(__MODULE__)} requires an `:attribute` option (an atom)"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    attribute = opts[:attribute]

    case Ash.Changeset.get_attribute(changeset, attribute) do
      nil ->
        :ok

      value ->
        case Territory.cast_input(value, []) do
          {:ok, _canonical} -> :ok
          _error -> {:error, field: attribute, message: "is not a valid territory"}
        end
    end
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    {:not_atomic,
     "AshLocalize territory validation runs against CLDR data and cannot be applied atomically"}
  end
end
