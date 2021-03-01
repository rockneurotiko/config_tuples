# ConfigTuples for releases

[![Build Status](https://travis-ci.org/rockneurotiko/config_tuples.svg?branch=master)](https://travis-ci.org/rockneurotiko/config_tuples)
[![Hex.pm](https://img.shields.io/hexpm/v/config_tuples.svg)](http://hex.pm/packages/config_tuples)
[![Hex.pm](https://img.shields.io/hexpm/dt/config_tuples.svg)](https://hex.pm/packages/config_tuples)
[![Hex.pm](https://img.shields.io/hexpm/dw/config_tuples.svg)](https://hex.pm/packages/config_tuples)
[![codecov](https://codecov.io/gh/rockneurotiko/config_tuples/branch/master/graph/badge.svg)](https://codecov.io/gh/rockneurotiko/config_tuples)
[![Inline docs](http://inch-ci.org/github/rockneurotiko/config_tuples.svg)](http://inch-ci.org/github/rockneurotiko/config_tuples)


ConfigTuples provides a release config provider that replaces config tuples (e.g `{:system, value}`) with their expected runtime value. It can be used on Distillery or Elixir releases!

## Usage

Documentation can be found at [https://hexdocs.pm/config_tuples](https://hexdocs.pm/config_tuples/readme.html).

Add the package by adding `config_tuples` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:config_tuples, "~> 0.4"}
  ]
end
```

Depending if you use Distillery or Elixir releases, you will need different configurations, check the corresponding section:

- [Distillery](#with-distillery)
- [Elixir Releases](#with-elixir-releases)

The documentation about the configuration semantics are at the bottom of the README, in the [Config Tuples section](#config-tuples).

### With Distillery

Add distillery to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:distillery, "~> 2.1"}
  ]
end
```

**Note: For Distillery 2.0 use the config_tuples version `~> 0.2` [You can see the documentation here](https://github.com/rockneurotiko/config_tuples/tree/v0.2.6)**

Add the provider distillery release in `rel/config.exs`

```elixir
release :myapp do
  # ...snip...
  set config_providers: [
    ConfigTuples.Provider
  ]
end
```

This will result in `ConfigTuples.Provider` being invoked during boot, at which point it
will evaluate the current configuration for all the apps and replace the config tuples when needed, persisting it in the configuration.

Use `mix distillery.release` to create your release!

### With Elixir Releases

On Elixir 1.9 native Releases has been added, and starting in version `0.4` you can have the awesome tuples semantic with them!

Add the provider to the elixir release in `mix.exs`:

``` elixir
def project do
  [
    app: :myapp,
    # ...
    releases: [
      myapp: [
        config_providers: [{ConfigTuples.Provider, ""}]
      ]
    ]
  ]
end
```

Use `mix release` to create your release!

If you are going to have `distillery` in your application dependencies, you will need to add this configuration to your `config.exs` in order to use the elixir release instead.

``` elixir
config :config_tuples, distillery: false
```

### Ignoring custom structs
A list of structs can be provided that will be ignored (ie: not transformed) by providing the `ignored_structs` config option as below. The `Regex` struct is always ignored by default, regardless of what is specified in the configuration.
``` elixir
config :config_tuples, ignored_structs: [MyModule.MyStruct]
```

## Config tuples

The config tuple always start with `:system`, and can have some options as keyword, the syntax looks like this:

- `{:system, env_name}`
- `{:system, env_name, opts}`

The available options are:
- `type`: Type to cast the value, one of `:string`, `:integer`, `:float`, `:atom`, `:boolean`. Default to `:string`
- `default`: Default value if the environment variable is not set. Defaults no `nil`
- `transform`: Function to transform the final value, the syntax is {Module, :function}
- `required`: Set to true if this environment variable needs to be set, if not set it will raise an error. Defaults to `false`

If you need to store the literal values `{:system, term()}`, `{:system, term(), Keyword.t()}`,
you can use `{:system, :literal, term()}` to disable ConfigTuples config interpolation. For example:

``` elixir
# This will store the value {:system, :foo}
config :my_app,
  value: {:system, :literal, {:system, :foo}}
```

Config tuples will replace your values inside of maps and lists (See the trade-offs section for lists)

## Example

This could be an example for the main app, Ecto repository and logger:

``` elixir
config :my_app,
  uri: {:system, "HOST", transform: {MyApp.UriParser, :parse}, required: true}

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

## Known trade-offs

### Module attributes

Sometimes in our apps we fetch the configuration values with module attributes, for example:

``` elixir
defmodule MyApp do
    @port Application.fetch_env!(:my_app, :port)

    # Use @port
end
```

When releasing your app with Distillery, your code is compiled when you execute `mix release`, and the config providers are executed just before booting your code.

This means that if you use module attributes for loading values expected to be replaced by any config provider, it won't be replaced, because that value will be setted on compile time, when doing the release (You can read more about module attributes [here](https://elixir-lang.org/getting-started/module-attributes.html))

Instead of module attributes you can use the following code:

``` elixir
defmodule MyApp do
    defp port, do: Application.fetch_env!(:my_app, :port)

    # Use port()
end
```

### Tuples inside of lists

ConfigTuples works recursively in maps and lists, which makes it unable to differentiate a keyword list (like the app config) with an element of the list with a 2-tuple, if you need to trigger ConfigTuples inside a list you need to pass some option as third parameter:

``` elixir
# Assuming that HOST=localhost
# :value option will have [{:system, "HOST"}, "localhost"]
config :my_app,
  value: [{:system, "HOST"}, {:system, "HOST", type: :string}]
```
