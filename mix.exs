defmodule Gameserver.MixProject do
  use Mix.Project

  def project do
    [
      app: :gameserver,
      version: "0.1.6",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Gameserver.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},
      {:credo, "~> 0.10.2", only: [:dev], runtime: false},
      {:ecs, git: "https://github.com/lytedev/ecs.git", tag: "v0.6.1"},
      {:math, "~> 0.3"},
      {:graphmath, "~> 1.0"},
      {:distillery, "~> 2.0"},
      {:socket, "~> 0.3.13"}
    ]
  end
end
