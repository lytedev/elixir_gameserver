defmodule Gameserver.MixProject do
  use Mix.Project

  def project do
    [
      app: :gameserver,
      version: "0.1.0",
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
      {:distillery, "~> 2.0"},
      {:socket, "~> 0.3.13"}
    ]
  end
end
