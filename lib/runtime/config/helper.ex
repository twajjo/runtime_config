defmodule Runtime.Config.Helper do
  @moduledoc """

  ## Valid options:
  
    type:
      :atom -
      :boolean -
      :charlist -
      :float, -
      :integer -
      :module -
      :string - 
      :list - 
      :tuple - 
      :map - 
    subtype: For lists and tuples
      :atom -
      :boolean -
      :charlist -
      :float, -
      :integer -
      :module -
      :string - 
      :map - 
    default: any() The default value 
    in_set: list() The value must be in the specified set of values of the same type.
    in_range: range()
    regex: 
    custom:
    NEW! required:

  """

  require Logger
  require Jason

  # TODO: New type candidates: :existing_atom? :map from JSON?
  @valid_types [
    :atom,
    :boolean,
    :charlist,
    :float,
    :integer,
    :module,
    :string,
    :list,
    :tuple,
    :map
  ]
  @valid_subtypes [
    :atom,
    :boolean,
    :charlist,
    :float,
    :integer,
    :module,
    :string,
    :map
  ]

  # Testing hooks
  defmodule System.Wrapper do
    defmodule API do
      @callback get_env(String.t(), String.t() | nil) :: String.t() | nil
    end

    @impl API
    def get_env(varname, default \\ nil) do
      System.get_env(varname, default)
    end
  end
  @system_module Application.get_env(:runtime_config, :helper_system, System.Wrapper)

  @doc """

  """
  def get_env(var_name, opts \\ []) when is_binary(var_name) do
    opts_map = Map.new(opts) |> Map.put_new(:_env_var, var_name)

    @system_module.get_env(var_name)
    |> parse(determine_type(opts), opts_map)
    |> validity_check(opts_map)
  end

  ## Private

  def determine_type(opts) do
    # Use the explicitly defined type if provided.
    # Unspecified type: try to determine from the data type of the default.
    # No default type: try to determine from the data type of the set (if :in_set specified).
    # TODO: (Maybe deterine from "in-range"?)
    # Must be a string, then...
    opts[:type] ||
      type_of(opts[:default]) ||
      (is_list(opts[:in_set]) && type_of(opts[:in_set] |> List.first())) ||
      :string
  end

  ## Error reporting
  defp error(msg) do
    Logger.error(msg)
    {:error, msg}
  end

  # Determine type from value.
  defp type_of(nil) do
    nil
  end
  defp type_of(value)
       when is_boolean(value) do
    :boolean
  end
  defp type_of(value)
       when is_integer(value) do
    :integer
  end
  defp type_of(value)
       when is_float(value) do
    :float
  end
  defp type_of(value)
       when is_atom(value) do
    case parse(value, :module, []) |> Code.ensure_compiled() do
      {:module, _} -> :module
      _ -> :atom
    end
  end
  defp type_of(value)
       when is_tuple(value) do
    :tuple
  end
  defp type_of(value)
       when is_list(value) do
    :list
  end
  # Value or default is not interpretable as type definition, so unspecified...
  defp type_of(_value) do
    nil
  end

  ## Parse based on determined type
  defp parse(nil, _type, %{default: default} = _opts) do
    default
  end
  defp parse(value, nil, opts) do
    parse(value, :string, opts)
  end
  defp parse(value, :string, _opts) do
    value
  end
  defp parse(value, :charlist, _opts) do
    value |> String.to_charlist()
  end
  defp parse(value, :boolean, opts) do
    value
    |> String.to_existing_atom()
    |> validity_check(Map.put_new(opts, :in_set, [true, false]))
  end
  defp parse(value, :integer, _opts) do
    value
    |> String.to_integer()
  end
  defp parse(value, :float, _opts) do
    value
    |> String.to_float()
  end
  defp parse(value, :tuple, opts) do
    value
    |> parse(:list, %{opts | subtype: opts[:subtype] || :string})
    |> List.to_tuple()
  end
  defp parse(value, :list, _opts) do
    value
    |> String.split(",")
    |> Enum.map(fn elem -> String.trim(elem) end)
    # TODO: parse according to subtype
  end
  defp parse(value, :module, _opts) do
    case value |> to_string() |> String.split(".") |> List.first() do
      "Elixir" -> :"#{value}"
      _ -> :"Elixir.#{value}"
    end
  end
  defp parse(value, :atom, _opts) do
    value
    |> String.to_atom()
  end
  defp parse(_value, type, opts) do
    error("#{opts._env_var}: Unrecognized type (#{inspect(type)}), supported types: #{inspect(@valid_types)}")
  end

  # Second, run built-in validators [:in_set, :in_range, :regex] and customs...

  defp validity_check(value, opts) when is_map(opts) do
    value
    |> check_type(opts)
    |> check_set(opts)
    |> check_range(opts)
    |> check_regex(opts)
    |> check_custom(opts)
    |> check_required(opts)
  end

  # Required checks
  defp check_required(nil, %{required: true} = opts) do
    error("#{opts._env_var}: value is required and no default was provided")
  end
  defp check_required({:error, _} = error, _opts) do
    error
  end
  defp check_required(value, _opts) do
    value
  end

  # Final result type checks
  defp check_type(nil, _opts) do
    nil
  end
  defp check_type({:error, _} = error, _opts) do
    error
  end
  defp check_type([], _opts) do
    []
  end
  defp check_type(list, %{subtype: subtype} = opts) when is_list(list) and subtype in @valid_subtypes do
    check_type(list, %{opts | subtype: List.duplicate(subtype, length(list))})
  end
  defp check_type([hv|tv], %{subtype: [hs|ts], type: type} = opts) when length(ts) == length(tv) do
    if type_of(hv) == hs do
      case check_type(tv, %{opts | subtype: ts}) do
        list when is_list(list) -> [hv] ++ list
        error -> error
      end
    else 
      error("#{opts._env_var}: value (#{inspect(hv)}) type (#{inspect(hs)}) mismatch in #{inspect(type)}")
    end
  end
  defp check_type([_|tv] = values, %{subtype: [_|ts] = types} = opts) when length(ts) != length(tv) do
    error("#{opts._env_var}: value list (#{inspect(values)}) length (#{length(tv)}) to " <>
      "type list (#{inspect(types)}) length (#{length(ts)}) mismatch in #{inspect(types)}")
  end
  defp check_type({} = value, %{subtype: subtype, type: :tuple} = opts) when subtype in @valid_subtypes do
    value
    |> Tuple.to_list
    |> check_type(opts)
  end
  defp check_type({} = value, %{subtype: {} = match, type: :tuple} = opts) do
    value
    |> Tuple.to_list
    |> check_type(%{opts | subtype: match |> Tuple.to_list()})
  end
  defp check_type(value, %{type: type} = opts) when type in @valid_types do
    if type_of(value) == :type do
      value 
    else
      error("#{opts._env_var}: value (#{inspect(value)}) type (#{inspect(type)}) mismatch")
    end
  end
  defp check_type(value, _opts) do
    value
  end

  # Run custome validators
  defp check_custom(nil, _opts) do
    nil
  end
  defp check_custom({:error, _} = error, _opts) do
    error
  end
  defp check_custom(value, %{custom: custom_validators} = opts)
       when is_list(custom_validators) do
    iterate_customs(value, opts, custom_validators)
  end
  defp check_custom(value, %{custom: {module, function}} = opts)
       when is_atom(module) and
              is_atom(function) do
    (Code.ensure_compiled?(module) &&
       {function, 2} in module.__info__(:functions) &&
       Kernel.apply(module, function, [value, opts])) ||
       error("#{opts._env_var}: custom validator module #{module} or function #{function} missing")
  end
  defp check_custom(value, _opts) do
    value
  end

  defp iterate_customs(value, _opts, []) do
    value
  end
  defp iterate_customs(value, opts, [custom | the_rest]) do
    value
    |> check_custom(%{opts | custom: custom})
    |> iterate_customs(opts, the_rest)
  end

  ## Check must-be-in-a-set validators for sets of atoms, numbers, strings, etc.
  defp check_set({:error, _} = error, _opts) do
    error
  end
  defp check_set(value, %{in_set: set} = opts) when is_list(set) do
    if Enum.member?(set, value) do
      value
    else
      error("#{opts._env_var}: value #{value} not in options #{inspect(set)}")
    end
  end
  defp check_set(value, _opts) do
    value
  end

  ## Check ordinal range validators...
  defp check_range({:error, _} = error, _opts) do
    error
  end
  defp check_range(value, %{in_range: range} = opts) do
    if Enum.member?(range, value) do
      value
    else
      error("#{opts._env_var}: value #{value} not in specified range #{inspect(range)}")
    end
  end
  defp check_range(value, _opts) do
    value
  end

  ## Check regex validators...
  defp check_regex({:error, _} = error, _opts) do
    error
  end
  defp check_regex(value, %{regex: regex} = opts) do
    if Regex.match?(regex, to_string(value)) do
      value
    else
      error("#{opts._env_var}: value #{value} does not match regex #{inspect(opts[:regex])}")
    end
  end
  defp check_regex(value, _opts) do
    value
  end
end
