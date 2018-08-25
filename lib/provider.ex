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

  The existing config tuples are:

  - `{:system, env_name}` - Read the env_name from environment variables (Using `System.get_env/1`)
  - `{:system, env_name, default}` - The same as `{:system, env_name}` but with a default value if no environment variable is set.
  - `{:integer, value}` - Parse the value as integer. Value can be other config tuple.
  - `{:atom, value}` - Parse the value as atom. Value can be other config tuple.
  - `{:boolean, value}` - Parse the value as boolean. Value can be other config tuple.

  With `:integer`, `:atom` and `:boolean` you can use another config tuples, for example: `{:integer, {:system, "MYSQL_PORT"}}`
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

  defp replace_value({:atom, bin}) when is_binary(bin), do: String.to_atom(bin)
  defp replace_value({:atom, value}), do: replace_value({:atom, replace_value(value)})

  defp replace_value({:integer, bin}) when is_binary(bin), do: String.to_integer(bin)
  defp replace_value({:integer, value}), do: replace_value({:integer, replace_value(value)})

  defp replace_value({:boolean, "true"}), do: true
  defp replace_value({:boolean, "false"}), do: false
  defp replace_value({:boolean, value}), do: replace_value({:boolean, replace_value(value)})

  defp replace_value({:system, env}), do: System.get_env(env)
  defp replace_value({:system, env, default}), do: System.get_env(env) || default

  defp replace_value(value), do: value

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
