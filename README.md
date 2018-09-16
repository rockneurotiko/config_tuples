# ConfigTuples for Distillery releases

[![Hex.pm](https://img.shields.io/hexpm/v/config_tuples.svg)](http://hex.pm/packages/config_tuples)
[![Hex.pm](https://img.shields.io/hexpm/dt/config_tuples.svg)](https://hex.pm/packages/config_tuples)
[![Hex.pm](https://img.shields.io/hexpm/dw/config_tuples.svg)](https://hex.pm/packages/config_tuples)
[![Inline docs](http://inch-ci.org/github/rockneurotiko/config_tuples.svg)](http://inch-ci.org/github/rockneurotiko/config_tuples)


ConfigTuples provides a distillery's config provider that replace config tuples (e.g `{:system, value}`) to their expected runtime value.

## Usage

Documentation can be found at [https://hexdocs.pm/config_tuples](https://hexdocs.pm/config_tuples/readme.html).

Add the package by adding `config_tuples` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:config_tuples, "~> 0.1.0"}
  ]
end
```

Then, add it to the config providers of distillery in `rel/config.exs`

``` elixir
release :myapp do
  # ...snip...
  set config_providers: [
    ConfigTuples.Provider
  ]
end
```

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

## Example

This could be an example for Ecto repository and logger:

``` elixir
config :my_app,
    uri: {:system, "HOST", transform: {MyApp.UriParser, :parse}}

config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.MySQL,
  username: {:system, "DATABASE_USERNAME", default: "root"},
  password: {:system, "DATABASE_PASSWORD", default: "toor"},
  database: {:system, "DATABASE_DB", default: "myapp"},
  hostname: {:system, "DATABASE_HOST", default: "localhost"},
  port: {:system, "DATABASE_PORT", type: :integer, default: 3306},
  pool_size: {:system, "DATABASE_POOL_SIZE", type: :integer, default: 10}

config :logger,
  level: {:system, "LOG_LEVEL", type: :atom, default: :info}
```
