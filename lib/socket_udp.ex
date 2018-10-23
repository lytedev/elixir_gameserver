defmodule Gameserver.Socket.UDP do
  use GenServer

  @moduledoc false

  alias Socket.Datagram, as: Datagram
  alias Socket.UDP, as: UDP

  require Logger

  @default_port 6090

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, name: :socket_udp)
  end

  def init(opts) do
    port = opts[:port] || @default_port
    Logger.info(fn -> "UDP Socket Opening at udp://0.0.0.0:#{port}" end)
    {:ok, socket} = UDP.open(port)
    state = %{socket: socket}
    Task.start_link(fn -> serve(self(), socket) end)
    {:ok, state}
  end

  def serve(server, socket) do
    {:ok, {data, remote_socket}} = Datagram.recv(socket)
    # TODO: call
    Logger.info(fn -> "UDP Socket Received: #{inspect(data)} from #{remote_socket}" end)
    serve(server, socket)
  end
end
