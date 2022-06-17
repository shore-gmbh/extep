defmodule Extep.MixProject do
  use Mix.Project

  def project do
    [
      app: :extep,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      package: package(),
      name: "Extep"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/sam-levy/extep"}
    ]
  end
end
