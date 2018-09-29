defmodule Gameserver.Socket do
  require Logger

  use Task

  @server_version "0.1.0"

  def start(opts) do
    Logger.info(
      "UDP socket open on 0.0.0.0:" <> to_string(opts[:port]) <> " - " <> inspect(opts[:socket])
    )

    serve(opts[:game], opts[:socket])
  end

  def serve(game, socket) do
    {:ok, {data, client}} = socket |> Socket.Datagram.recv()
    # Logger.debug("Message Received: #{inspect(data)}\tFrom: #{inspect(client)}")
    handle_message(data, client, socket, game)
    serve(game, socket)
  end

  defp broadcast(message, socket, game) do
    {:ok, clients} = Gameserver.call_get_all_clients(game) |> IO.inspect()

    clients
    |> Enum.each(fn {k, v} ->
      Socket.Datagram.send(socket, message, k)
    end)
  end

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

    broadcast("new_client #{new_client[:id]}", socket, game)
  end

  defp handle_message("quit", client, socket, game) do
    # TODO: handle errors
    {:ok, old_client} = Gameserver.call_remove_client(game, client)

    Logger.debug("Quitter: #{inspect(old_client)} over #{inspect(socket)}")

    broadcast("remove_client #{old_client[:id]}", socket, game)
  end

  defp handle_message("up " <> update_data_string, client, socket, game) do
    # TODO: handle errors
    [raw_inputs, raw_aimpos] = String.split(update_data_string, " ")

    to_integer_list = fn e ->
      String.split(e, ",")
      |> Enum.map(&Integer.parse/1)
      |> Enum.map(&elem(&1, 0))
    end

    input_zipper = fn l ->
      Enum.zip([:up, :down, :left, :right, :fire], l)
      |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, k, v) end)
    end

    inputs =
      raw_inputs
      |> to_integer_list.()
      |> input_zipper.()

    aimpos = raw_aimpos |> to_integer_list.() |> List.to_tuple()

    {:ok, client} =
      Gameserver.call_update_client(game, {client, %{inputs: inputs, aimpos: aimpos}})

    # Logger.debug("Update: #{inspect(client)} over #{inspect(socket)}")
  end

  defp handle_message(m, client, socket, game) do
    Logger.debug(
      "Bad Message Received: #{inspect(m <> <<0>>)} from #{inspect(client)} over #{
        inspect(socket)
      }"
    )
  end
end
