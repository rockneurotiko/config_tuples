defmodule ConfigTuples.MixProject do
  use Mix.Project

  def project do
    [
      app: :config_tuples,
      version: "0.1.0",
      elixir: "~> 1.6",
      package: package(),
      description: description(),
      source_url: "https://github.com/rockneurotiko/config_tuples",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "README.md"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Miguel Garcia / Rock Neurotiko"],
      licenses: ["Beerware"],
      links: %{"GitHub" => "https://github.com/rockneurotiko/config_tuples"}
    ]
  end

  defp description do
    "ConfigTuples provides a distillery's config provider that replace config tuples (e.g `{:system, value}`) to their expected runtime value."
  end

  defp deps do
    [
      {:distillery, "~> 2.0", runtime: false},
      {:ex_doc, "~> 0.18.0", only: :dev}
    ]
  end
end
