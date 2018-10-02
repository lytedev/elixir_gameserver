defmodule Gameserver.Socket do
  require Logger

  use Task

  @server_version "0.1.2"

  def start(opts) do
    Logger.info(
      "Socket Open: udp://0.0.0.0:#{to_string(opts[:port])} - #{inspect(opts[:socket])}"
    )

    serve(opts[:game], opts[:socket])
  end

  @doc """
  The socket loop.
  """
  def serve(game, socket) do
    {:ok, {data, client}} = Socket.Datagram.recv(socket)
    # Logger.debug("Message Received: #{inspect(data)}\tFrom: #{inspect(client)}")
    handle_message(data, client, socket, game)
    serve(game, socket)
  end

  def broadcast(message, socket, game, nil) do
    broadcast(message, socket, game, Gameserver.call_get_all_clients(game))
  end

  def broadcast(message, socket, game, clients) do
    clients
    |> Enum.each(fn {k, v} ->
      Socket.Datagram.send(socket, message, k)
    end)
  end

  # message handlers
  defp handle_message("l2d_test_game v#{@server_version} connect", client, socket, game) do
    # TODO: handle errors

    {:ok, new_client} = Gameserver.call_new_client(game, client)

    Logger.debug("New Client: #{inspect(new_client)} over #{inspect(socket)}")

    :ok =
      Socket.Datagram.send(
        socket,
        "l2d_test_game v#{@server_version} accepted #{new_client[:id]}",
        client
      )
  end

  defp handle_message("l2d_test_game v" <> version <> " connect", client, socket, game) do
    :ok =
      Socket.Datagram.send(
        socket,
        "disconnected invalid_version client:#{version} server:#{@server_version}",
        client
      )
  end

  defp handle_message("quit", client, socket, game) do
    {:ok, old_client} = Gameserver.call_remove_client(game, client)
    Logger.debug("Client Disconnected: #{inspect(old_client)} over #{inspect(socket)}")
  end

  defp handle_message("up " <> update_data_string, client, socket, game) do
    {:ok, inputs, aimpos} = Gameserver.Client.parse_client_update_packet(update_data_string)

    case Gameserver.call_update_client(game, {client, %{inputs: inputs, aimpos: aimpos}}) do
      {:ok, client} ->
        nil

      _ ->
        nil
        # Logger.error(
        #   "Received bad client update: #{inspect(update_data_string)} from #{inspect(client)} over #{
        #     inspect(socket)
        #   }\nState: #{inspect("TODO")}"
        # )
    end

    # Logger.debug("Update: #{inspect(client)} over #{inspect(socket)}")
  end

  defp handle_message(m, client, socket, game) do
    # Logger.debug(
    # "Bad Message Received: #{inspect(m <> <<0>>)} from #{inspect(client)} over #{
    # inspect(socket)
    # }"
    # )
  end
end
