defmodule Gameserver.Application do
  alias Gameserver.Worker

  use Application

  def start(_type, _args) do
    children = [
      {Gameserver, [name: :game]}
    ]

    opts = [strategy: :one_for_one, name: Gameserver.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
