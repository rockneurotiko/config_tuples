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
  - `type`: Type to cast the value, one of `:string`, `:integer`, `:atom`, `:boolean`. Default to `:string`
  - `default`: Default value if the environment variable is not setted. Default no `nil`
  - `transform`: Function to transform the final value, the syntax is {Module, :function}

  For example:
  - `{:system, "MYSQL_PORT", type: :integer, default: 3306}`
  - `{:system, "ENABLE_LOG", type: :boolean, default: false}`
  - `{:system, "HOST", transform: {MyApp.UrlParser, :parse}}`
  """

  use Mix.Releases.Config.Provider

  @impl Provider
  def init(_cfg) do
    # Build up configuration and persist

    for {app, _, _} <- Application.loaded_applications() do
      fix_app_env(app)
    end
  end

  defp fix_app_env(app) do
    base = Application.get_all_env(app)

    new_config = replace(base)

    merged = deep_merge(base, new_config)

    persist(app, merged)
  end

  defp persist(_app, []), do: :ok

  defp persist(app, [{k, v} | rest]) do
    Application.put_env(app, k, v, persistent: true)
    persist(app, rest)
  end

  defp replace({key, {kind, value}}), do: {key, replace_value({kind, value})}
  defp replace({key, {kind, value, default}}), do: {key, replace_value({kind, value, default})}
  defp replace({key, list}) when is_list(list), do: {key, replace(list)}
  defp replace({key, other}), do: {key, other}

  defp replace([]), do: []
  defp replace(list) when is_list(list), do: Enum.map(list, &replace/1)
  defp replace(other), do: other

  defp replace_value({:system, env}), do: replace_value({:system, env, []})

  defp replace_value({:system, env, opts}) do
    type = Keyword.get(opts, :type, :string)
    default = Keyword.get(opts, :default)
    transformer = Keyword.get(opts, :transform)

    env |> get_env_value(type, default) |> transform(transformer)
  end

  defp get_env_value(env, type, default) do
    case System.get_env(env) do
      nil -> default
      value -> cast(value, type)
    end
  end

  defp transform(value, nil), do: value

  defp transform(value, {module, function}) do
    apply(module, function, [value])
  end

  defp cast(nil, _type), do: nil
  defp cast(value, :string), do: value
  defp cast(value, :atom), do: String.to_atom(value)
  defp cast(value, :integer), do: String.to_integer(value)
  defp cast("true", :boolean), do: true
  defp cast("false", :boolean), do: false
  defp cast(_, :boolean), do: false

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
