defmodule Gameserver.Socket.Web do
  use GenServer

  @moduledoc false

  alias Socket.Web, as: Web

  require Logger

  @type disconnect :: {:disconnect, %Web{}}

  @default_port 6090
  @protocol_version "0.1.7"
  @protocol_prefix "tanks"
  @accept_opts protocol: @protocol_prefix <> @protocol_version

  @initial_state %{
    clients: %{}
  }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, name: :socket_web)
  end

  @spec init(Keyword.t()) :: {:ok, map}
  def init(opts) do
    port = opts[:port] || @default_port
    Logger.info(fn -> "WebSocket Opening at ws://0.0.0.0:#{port}" end)

    socket = Web.listen!(port)

    state = Map.put(@initial_state, :socket, socket)
    Task.start_link(__MODULE__, :accept_connections, [self(), socket])
    {:ok, state}
  rescue
    err -> {:stop, err}
  end

  @spec handle_call(any, any, map) :: {:reply, tuple, map}

  def handle_call({:new_client, client}, _from, state) do
    state = %{state | clients: Map.put(state.clients, client.key, client)}
    {:reply, {:ok, client.key, client}, state}
  end

  @spec accept_connections(any, %Web{}) :: no_return
  def accept_connections(server, socket) do
    socket
    |> Web.accept!(@accept_opts)
    |> init_client(server, socket)

    accept_connections(server, socket)
  end

  @spec init_client(any, %Web{}) :: no_return
  def init_client(client, server, socket) do
    # TODO: protocol version verificiation
    client
    |> Web.accept!(@accept_opts)

    server
    |> GenServer.call({:new_client, client})
    |> init_client(client)
  end

  def init_client({:ok, client_key, added_client}, client) do
    Logger.info(fn ->
      "Accepted WebSocket Connection: #{inspect(client_key)} => #{inspect(added_client)}"
    end)

    spawn(fn -> serve({:ok, client}) end)
  end

  def init_client(_, client) do
    Logger.info(fn -> "Failed to add new client: #{inspect(client)}" end)
  end

  @spec serve({:ok, %Web{}} | {:disconnect, %Web{}}) :: no_return
  def serve({:disconnect, client}) do
    Web.close(client)
    Logger.info(fn -> "WebSocket Client Disconnected: #{inspect(client)}" end)
    disconnect(client)
  end

  def serve({:ok, client}) do
    client
    |> receive_msg()
    |> serve()
  end

  @spec receive_msg(%Web{}) :: {:ok, %Web{}} | disconnect
  def receive_msg(client) do
    client
    |> Web.recv!()
    |> handle_msg(client)
  end

  @spec handle_msg(any | {atom, any} | {atom, any, any}, %Web{}) :: {:ok, %Web{}} | disconnect
  def handle_msg({:text, data}, client) do
    Logger.info(fn -> "WebSocket Received: #{inspect(data)} from #{inspect(client)}" end)
    {:ok, client}
  end

  def handle_msg({:close, reason, text}, client) do
    Logger.info(fn -> "WebSocket Client Close: #{inspect({reason, text})}" end)
    disconnect(client)
  end

  def handle_msg(:close, client) do
    Logger.info(fn -> "WebSocket Client Close: <No Reason Given>" end)
    disconnect(client)
  end

  def handle_msg({:close, reason}, client) do
    Logger.info(fn -> "WebSocket Client Close: #{inspect(reason)}" end)
    disconnect(client)
  end

  def handle_msg({:error, error}, client) do
    Logger.info(fn -> "WebSocket Receive Error: #{inspect(error)}" end)
    disconnect(client)
  end

  def handle_msg(x, client) do
    Logger.info(fn -> "WebSocket Unknown Message Type: #{inspect(x)}" end)
    disconnect(client)
  end

  @spec disconnect(%Web{}) :: disconnect
  defp disconnect(client) do
    {:disconnect, client}
  end
end
