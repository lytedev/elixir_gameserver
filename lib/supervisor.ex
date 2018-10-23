defmodule Gameserver.Supervisor do
  use Supervisor

  @moduledoc false

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {Gameserver, name: :game},
      {Gameserver.Socket.UDP, name: :socket_udp},
      {Gameserver.Socket.Web, name: :socket_web}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
