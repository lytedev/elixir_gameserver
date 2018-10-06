defmodule Gameserver.Socket do
  require Logger

  use Task

  # TODO: binary protocol? need easy way to send floats and ints

  def start(opts) do
    Logger.info("Socket Open: udp://0.0.0.0:#{to_string(opts.port)} - #{inspect(opts.socket)}")

    serve(opts.game, opts.socket, opts.server_version)
  end

  @doc """
  The socket loop.
  """
  def serve(game, socket, server_version) do
    {:ok, {data, client}} = Socket.Datagram.recv(socket)
    # Logger.debug("Message Received: #{inspect(data)}\tFrom: #{inspect(client)}")
    handle_message(data, client, socket, game, server_version)
    serve(game, socket, server_version)
  end

  def screen_message(message, socket, clients) do
    broadcast("msg " <> message, socket, nil, clients)
  end

  def broadcast(message, socket, game, nil) do
    broadcast(message, socket, game, Gameserver.call_get_all_clients(game))
  end

  def broadcast(message, socket, _, clients) do
    clients
    |> Enum.each(fn {k, v} ->
      Socket.Datagram.send(socket, message, k)
    end)
  end

  defp handle_message("l2d_test_game v" <> v, client, socket, game, server_version) do
    name =
      case Regex.run(~r/connect ([[:graph:]]+)/, v) do
        n when n in [:error, nil] ->
          :ok =
            Socket.Datagram.send(
              socket,
              "disconnected invalid_name",
              client
            )

          nil

        [_, name | _] ->
          name
      end

    if String.starts_with?(v, server_version) do
      # TODO: check that "connect" is in there
      # extract initial name?

      {:ok, new_client} = Gameserver.call_new_client(game, client, name: name)
    else
      :ok =
        Socket.Datagram.send(
          socket,
          "disconnected invalid_version_connect client:#{v} server:#{server_version} connect",
          client
        )
    end
  end

  defp handle_message("quit", client, socket, game, server_version) do
    {:ok, old_client} = Gameserver.call_remove_client(game, client)
  end

  defp handle_message("up " <> update_data_string, client, socket, game, server_version) do
    {:ok, inputs, aimpos, active_weapon, active_secondary_weapon} =
      Gameserver.Client.parse_client_update_packet(update_data_string)

    case Gameserver.call_update_client(
           game,
           {client,
            %{
              inputs: inputs,
              aimpos: aimpos,
              since_last_update: 0,
              active_weapon: active_weapon,
              active_secondary_weapon: active_secondary_weapon
            }}
         ) do
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

  defp handle_message("name " <> name, client, socket, game, server_version) do
    case Gameserver.call_update_client_name(game, client, name) do
      {:ok, new_name} -> nil
      _ -> nil
    end
  end

  defp handle_message(m, client, socket, game, _) do
    Logger.debug(fn ->
      "Bad Message Received: #{inspect(m <> <<0>>)} from #{inspect(client)} over #{
        inspect(socket)
      }"
    )
  end
end
