defmodule ConfigTuples.Provider do
  @moduledoc """
  This module provides an implementation of Distilery's configuration provider
  behavior that changes runtime config tuples for the value.

  ## Usage
  Add the following to your `rel/config.exs`

    release :myapp do
      # ...snip...
      set config_providers: [
        ConfigTuples.Provider
      ]
    end

  This will result in `ConfigTuples.Provider` being invoked during boot, at which point it
  will evaluate the current configuration for all the apps and replace the config tuples when needed, persisting it in the configuration.

  ## Config tuples

  The config tuple always start with `:system`, and can have some options as keyword, the syntax are like this:

  - `{:system, env_name}`
  - `{:system, env_name, opts}`

  The available options are:
  - `type`: Type to cast the value, one of `:string`, `:integer`, `:float`, `:atom`, `:boolean`. Default to `:string`
  - `default`: Default value if the environment variable is not setted. Default no `nil`
  - `transform`: Function to transform the final value, the syntax is {Module, :function}
  - `required`: Set to true if this environment variable needs to be setted, if not setted it will raise an error. Default no `false`

  For example:
  - `{:system, "MYSQL_PORT", type: :integer, default: 3306}`
  - `{:system, "ENABLE_LOG", type: :boolean, default: false}`
  - `{:system, "HOST", transform: {MyApp.UrlParser, :parse}}`

  If you need to store the literal values `{:system, term()}`, `{:system, term(), Keyword.t()}`,
  you can use `{:system, :literal, term()}` to disable ConfigTuples config interpolation. For example:

  - `{:system, :literal, {:system, "HOST}}`
  """

  @distillery_loaded Code.ensure_loaded?(Distillery.Releases.Config.Provider)

  if @distillery_loaded do
    @behaviour Distillery.Releases.Config.Provider
  else
    @behaviour Config.Provider
  end

  @ignore_structs [Regex]

  def init(_cfg) do
    if use_distillery() do
      distillery_provider()
    end
  end

  def load(config, _) do
    elixir_provider(config)
  end

  defp use_distillery() do
    @distillery_loaded and Application.get_env(:config_tuples, :distillery, true)
  end

  defp distillery_provider() do
    # Build up configuration and persist
    for {app, _, _} <- Application.loaded_applications() do
      fix_app_env(app)
    end
  end

  defp elixir_provider(config) do
    new_config = config |> filter_elixir_config() |> replace()

    deep_merge(config, new_config)
  end

  @elixir_apps [:elixir, :kernel]

  defp filter_elixir_config(config) do
    Keyword.drop(config, @elixir_apps)
  end

  defp fix_app_env(app) do
    base = Application.get_all_env(app)

    new_config = replace(base)

    # We have to wrap with the app name, just in case we use Config.Reader
    [{_app, merged}] = deep_merge([{app, base}], [{app, new_config}])

    persist(app, merged)
  end

  defp persist(_app, []), do: :ok

  defp persist(app, [{k, v} | rest]) do
    Application.put_env(app, k, v, persistent: true)
    persist(app, rest)
  end

  def replace({:system, :literal, value}), do: value
  def replace({:system, value}), do: replace_value(value, [])
  def replace({:system, value, opts}), do: replace_value(value, opts)

  def replace(from..to) do
    from..to
  end

  def replace(list) when is_list(list) do
    Enum.map(list, fn
      {key, value} -> {replace(key), replace(value)}
      other -> replace(other)
    end)
  end

  def replace(%{__struct__: struct} = value) when struct in @ignore_structs, do: value

  def replace(%{__struct__: struct} = value) do
    values = value |> Map.from_struct() |> replace()
    struct(struct, values)
  end

  def replace(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {replace(key), replace(value)} end)
  end

  def replace(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&replace/1) |> List.to_tuple()
  end

  def replace(other), do: other

  defp replace_value(env, opts) do
    type = Keyword.get(opts, :type, :string)
    default = Keyword.get(opts, :default)
    required = Keyword.get(opts, :required, false)
    transformer = Keyword.get(opts, :transform)

    case fetch_env_value(env, type) do
      {:ok, env_value} -> transform(env_value, transformer)
      {:error, _} = error when required == true -> raise ConfigTuples.Error, error
      {:error, _} -> default
    end
  end

  defp fetch_env_value(env, type) do
    case System.get_env(env) do
      nil -> {:error, {:required, env}}
      value -> {:ok, cast(value, type)}
    end
  end

  defp transform(value, nil), do: value
  defp transform(value, {module, function}), do: apply(module, function, [value])

  defp cast(nil, _type), do: nil
  defp cast(value, :string), do: value
  defp cast(value, :atom), do: String.to_atom(value)
  defp cast(value, :integer), do: String.to_integer(value)
  defp cast(value, :float), do: String.to_float(value)
  defp cast("true", :boolean), do: true
  defp cast("false", :boolean), do: false
  defp cast(_, :boolean), do: false

  if Code.ensure_loaded?(Config.Reader) do
    defp deep_merge(base, extra) do
      Config.Reader.merge(base, extra)
    end
  else
    defp deep_merge(a, b) when is_list(a) and is_list(b) do
      if Keyword.keyword?(a) and Keyword.keyword?(b) do
        Keyword.merge(a, b, &deep_merge/3)
      else
        b
      end
    end

    defp deep_merge(_k, a, b) when is_list(a) and is_list(b) do
      if Keyword.keyword?(a) and Keyword.keyword?(b) do
        Keyword.merge(a, b, &deep_merge/3)
      else
        b
      end
    end

    defp deep_merge(_k, a, b) when is_map(a) and is_map(b) do
      Map.merge(a, b, &deep_merge/3)
    end

    defp deep_merge(_k, _a, b), do: b
  end
end
