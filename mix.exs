defmodule Extep.MixProject do
  use Mix.Project

  def project do
    [
      app: :extep,
      name: "Extep",
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      ],
      description: "A tiny and friendly step runner for Elixir pipelines",
      package: package(),
      source_url: "https://github.com/shore-gmbh/extep",
      docs: [
        main: "Extep",
        source_url: "https://github.com/shore-gmbh/extep",
        extras: [
          "README.md": [title: "Overview"],
          LICENSE: [title: "License"]
        ]
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
      name: "extep",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/shore-gmbh/extep"},
      maintainers: ["Shore GmbH"]
    ]
  end
end
