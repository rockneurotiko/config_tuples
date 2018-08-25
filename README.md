# ConfigTuples for Distillery releases

ConfigTuples provides a distillery's config provider that replace config tuples (e.g `{:system, value}`) to their expected runtime value.

## Usage

Documentation can be found at [https://hexdocs.pm/config_tuples](https://hexdocs.pm/config_tuples).

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

The existing config tuples are:

- `{:system, env_name}` - Read the env_name from environment variables (Using `System.get_env/1`)
- `{:system, env_name, default}` - The same as `{:system, env_name}` but with a default value if no environment variable is set.
- `{:integer, value}` - Parse the value as integer. Value can be other config tuple.
- `{:atom, value}` - Parse the value as atom. Value can be other config tuple.
- `{:boolean, value}` - Parse the value as boolean. Value can be other config tuple.

With `:integer`, `:atom` and `:boolean` you can use another config tuples, for example: `{:integer, {:system, "MYSQL_PORT"}}`

## Example

This could be an example for Ecto repository and logger:

``` elixir
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.MySQL,
  username: {:system, "DATABASE_USERNAME", "root"},
  password: {:system, "DATABASE_PASSWORD", "toor"},
  database: {:system, "DATABASE_DB", "myapp"},
  hostname: {:system, "DATABASE_HOST", "localhost"},
  port: {:integer, {:system, "DATABASE_PORT", "3306"}},
  pool_size: {:integer, {:system, "DATABASE_POOL_SIZE", "10"}}

config :logger,
  level: {:atom, {:system, "LOG_LEVEL", "info"}}
```
