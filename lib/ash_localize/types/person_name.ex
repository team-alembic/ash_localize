if Code.ensure_loaded?(Localize.PersonName) do
  defmodule AshLocalize.Types.PersonName do
    @moduledoc """
    An `Ash.Type` for a person's name, CLDR-aware via Localize.

    Stored as a map of name parts; the loaded value is a `%Localize.PersonName{}` struct
    that renders itself locale-appropriately — see `AshLocalize.Calculations.FormatPersonName`.

        attribute :author_name, :person_name

    Casting accepts a map of name parts with atom or string keys, or an existing
    `%Localize.PersonName{}`. A `:given_name` is required. Blank string parts cast to
    `nil`, and a map whose parts are all blank casts to `nil`, so an untouched form
    clears the attribute.

    ## Name parts

    `:title`, `:given_name`, `:other_given_names`, `:informal_given_name`,
    `:surname_prefix`, `:surname`, `:other_surnames`, `:generation`, `:credentials`,
    `:preferred_order`, `:locale`.

    Requires the optional `:localize_person_names` dependency. Without it this module is
    not compiled and `:person_name` does not resolve.
    """

    use Ash.Type

    @fields ~w(title given_name other_given_names informal_given_name surname_prefix
               surname other_surnames generation credentials preferred_order locale)a

    @impl true
    def storage_type(_constraints), do: :map

    @impl true
    def cast_input(nil, _constraints), do: {:ok, nil}
    def cast_input(%Localize.PersonName{} = name, _constraints), do: {:ok, name}

    def cast_input(map, _constraints) when is_map(map) do
      case map |> name_parts() |> Enum.reject(&blank?/1) do
        [] -> {:ok, nil}
        parts -> new_name(parts)
      end
    end

    def cast_input(_value, _constraints), do: {:error, message: "is not a valid person name"}

    @impl true
    def cast_stored(nil, _constraints), do: {:ok, nil}

    def cast_stored(map, _constraints) when is_map(map) do
      {:ok, struct(Localize.PersonName, name_parts(map))}
    end

    def cast_stored(_value, _constraints), do: :error

    @impl true
    def dump_to_native(nil, _constraints), do: {:ok, nil}

    def dump_to_native(%Localize.PersonName{} = name, _constraints),
      do: {:ok, Map.from_struct(name)}

    def dump_to_native(_value, _constraints), do: :error

    defp new_name(parts) do
      case Localize.PersonName.new(parts) do
        {:ok, name} -> {:ok, name}
        {:error, _reason} -> {:error, message: "is not a valid person name"}
      end
    end

    # HTML forms submit an empty text input as "".
    defp blank?({_field, nil}), do: true
    defp blank?({_field, value}) when is_binary(value), do: String.trim(value) == ""
    defp blank?(_part), do: false

    # Collect the known name-part fields from a map that may use atom or string keys.
    defp name_parts(map) do
      Enum.flat_map(@fields, fn field ->
        case fetch(map, field) do
          {:ok, value} -> [{field, value}]
          :error -> []
        end
      end)
    end

    defp fetch(map, field) do
      case Map.fetch(map, field) do
        {:ok, value} -> {:ok, value}
        :error -> Map.fetch(map, Atom.to_string(field))
      end
    end
  end
end
