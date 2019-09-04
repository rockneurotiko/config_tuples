defmodule ConfigTuples.ProviderElixirTest do
  use ExUnit.Case, async: false

  alias ConfigTuples.Provider

  setup do
    Application.put_env(:config_tuples, :distillery, false)
    :ok
  end

  defmodule CustomStruct do
    defstruct [:domain]
  end

  alias __MODULE__.CustomStruct

  describe "basic tests" do
    test "do not replace data without system tuple" do
      envs = %{}

      config = [
        host: "localhost",
        environment: :system,
        system: :production,
        port: 8080,
        ssl: true,
        some_range: 1..2
      ]

      env_scope(envs, fn ->
        assert_config(config, config)
      end)
    end

    test "replace basic tuple" do
      envs = %{"HOST" => "localhost"}
      config = [host: {:system, "HOST"}]
      expected_config = [host: "localhost"]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end
  end

  describe "type casts" do
    test "cast to integer" do
      envs = %{"PORT" => "8080"}
      config = [host: {:system, "PORT", type: :integer}]
      expected_config = [host: 8080]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end

    test "cast to float" do
      envs = %{"PERCENT" => "33.3"}
      config = [percent: {:system, "PERCENT", type: :float}]
      expected_config = [percent: 33.3]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end

    test "cast to atom" do
      envs = %{"LOG_LEVEL" => "info", "ADAPTER" => "Elixir.Some.Atom"}

      config = [
        log_level: {:system, "LOG_LEVEL", type: :atom},
        adapter: {:system, "ADAPTER", type: :atom}
      ]

      expected_config = [log_level: :info, adapter: Some.Atom]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end

    test "cast to boolean" do
      envs = %{"TRUTHY" => "true", "FALSEY" => "false", "OTHER" => "wat"}

      config = [
        truthy: {:system, "TRUTHY", type: :boolean},
        falsey: {:system, "FALSEY", type: :boolean},
        other: {:system, "OTHER", type: :boolean}
      ]

      expected_config = [truthy: true, falsey: false, other: false]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end
  end

  describe "default option" do
    test "default value is nil" do
      envs = %{}
      config = [host: {:system, "HOST"}]
      expected_config = [host: nil]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end

    test "set default value when no env" do
      envs = %{}

      config = [
        string: {:system, "STRING", default: "cool value"},
        integer: {:system, "INTEGER", type: :integer, default: 80},
        float: {:system, "FLOAT", type: :float, default: 33.3},
        atom: {:system, "ATOM", type: :atom, default: :info},
        boolean: {:system, "BOOL", type: :boolean, default: false}
      ]

      expected_config = [string: "cool value", integer: 80, float: 33.3, atom: :info, boolean: false]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end
  end

  describe "literal option" do
    test "when tuple contains literal use the value passed" do
      envs = %{"HOST" => "localhost"}

      config = [
        host: {:system, :literal, {:system, "HOST"}}
      ]

      expected_config = [host: {:system, "HOST"}]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end
  end

  describe "enumerable replaces" do
    test "replace values inside a map" do
      envs = %{"HOST" => "localhost"}

      config = [
        config: %{app: %{"host" => {:system, "HOST"}, "other" => "foo"}, other: "bar"}
      ]

      expected_config = [config: %{app: %{"host" => "localhost", "other" => "foo"}, other: "bar"}]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end

    test "do not replace 2-tuple inside a list" do
      envs = %{"HOST" => "localhost"}

      config = [
        system: "HOST",
        list: ["foo", 123, {:system, "HOST"}]
      ]

      expected_config = [system: "HOST", list: ["foo", 123, {:system, "HOST"}]]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end

    test "replace value inside a list if it's not a 2-tuple" do
      envs = %{"HOST" => "localhost"}

      config = [
        system: "HOST",
        list: ["foo", 123, {:system, "HOST", type: :string}]
      ]

      expected_config = [system: "HOST", list: ["foo", 123, "localhost"]]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end
  end

  describe "required option" do
    test "raise an error when a variable is required but is not setted" do
      envs = %{}

      config = [
        my_app: [
          var: {:system, "PORT", type: :integer, required: true}
        ]
      ]

      message = "environment variable 'PORT' required but is not setted"

      env_scope(envs, fn ->
        assert_raise(ConfigTuples.Error, message, fn ->
          Provider.load(config, :ok)
        end)
      end)
    end

    test "do not raise when a variable is required and is setted" do
      envs = %{"PORT" => "4321"}

      config = [
        var: {:system, "PORT", type: :integer, required: true}
      ]

      expected_config = [var: 4321]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end
  end

  def transform(x) do
    {x, "transformed"}
  end

  describe "transform option" do
    test "call the transform method with the correct value" do
      envs = %{"HOST" => "localhost", "PORT" => "8080"}

      config = [
        host: {:system, "HOST", transform: {__MODULE__, :transform}},
        port: {:system, "PORT", type: :integer, transform: {__MODULE__, :transform}}
      ]

      expected_config = [host: {"localhost", "transformed"}, port: {8080, "transformed"}]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end
  end

  describe "ignore structs" do
    test "ignore regex structs" do
      envs = %{"HOST" => "localhost"}

      config = [
        host: {:system, "HOST"},
        regex: ~r/.+/
      ]

      expected_config = [
        host: "localhost",
        regex: ~r/.+/
      ]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end

    test "does not ignore other structs" do
      envs = %{"HOST" => "localhost"}

      config = [
        my_struct: %CustomStruct{domain: {:system, "HOST"}}
      ]

      expected_config = [
        my_struct: %CustomStruct{domain: "localhost"}
      ]

      env_scope(envs, fn ->
        assert_config(config, expected_config)
      end)
    end
  end

  defp assert_config(config, expected) do
    config = [my_app: config]
    expected = [my_app: expected]

    compare_config(expected, Provider.load(config, :ok))
  end

  defp compare_config(config, other_config) do
    config = config |> Keyword.to_list() |> Enum.sort()
    other_config = other_config |> Keyword.to_list() |> Enum.sort()

    assert config == other_config
  end

  defp env_scope(envs, callback) do
    Enum.each(envs, fn {k, v} -> System.put_env(k, v) end)

    try do
      callback.()
    after
      clean_env(envs)
    end
  end

  defp clean_env(envs) do
    Enum.each(envs, fn {k, _v} -> System.delete_env(k) end)
  end
end
