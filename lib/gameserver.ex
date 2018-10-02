defmodule Gameserver do
  require Logger
  use GenServer

  # TODO: cleanup clients that haven't sent data in some time
  # TODO: handle crashes gracefully with regards to connected clients

  @default_port 6090
  # ~60 UPS
  @update_time_ms 16

  @initial_state %{
    last_tick: 0,
    clients: %{},
    bullets: %{},
    next_bullet_id: 0
  }

  def init(state) do
    schedule_update()
    {:ok, socket, _pid} = open_socket(state)

    Logger.debug("Game Process init() Complete: (Self: #{inspect(self())}")

    {:ok, Map.merge(state, %{last_tick: DateTime.utc_now(), socket: socket})}
  end

  def open_socket(state) do
    # TODO: supervised, so the socket can restart without restarting the entire
    # game
    # start a socket for network interactions
    port = state[:port] || @default_port
    {:ok, socket} = Socket.UDP.open(port)

    {:ok, pid} =
      Task.start_link(Gameserver.Socket, :start, [%{socket: socket, game: self(), port: port}])

    {:ok, socket, pid}
  end

  def start_link(_opts), do: GenServer.start_link(__MODULE__, @initial_state)

  # internal helpers
  def call_get_all_clients(game), do: GenServer.call(game, :get_all_clients)
  def call_new_client(game, client), do: GenServer.call(game, {:new_client, client})
  def call_remove_client(game, client), do: GenServer.call(game, {:remove_client, client})

  def call_update_client(game, {client, data}),
    do: GenServer.call(game, {:update_client, client, data})

  # TODO: handle errors
  defp handle_call_wrapper(res, error_callback \\ fn x -> x end)

  defp handle_call_wrapper({:ok, reply, state}, _error_callback),
    do: {:reply, {:ok, reply}, state}

  defp handle_call_wrapper({_, _reply, state}, error_callback),
    do: {:reply, :error, state} |> error_callback.()

  # genserver callbacks
  def handle_call(:get_all_clients, _from, state), do: {:reply, {:ok, state.clients}, state}

  def handle_call({:new_client, client}, _from, state),
    do: handle_call_wrapper(new_client(state, client))

  def handle_call({:remove_client, client}, _from, state),
    do: handle_call_wrapper(remove_client(state, client))

  def handle_call({:update_client, client, data}, _from, state) do
    handle_call_wrapper(update_client(state, client, data), fn x ->
      Socket.Datagram.send(state.socket, "disconnected client_not_found", client)
      x
    end)
  end

  # mutations
  defp new_client(state, client) do
    new_client_data = %Gameserver.Client{client: client}
    state = Map.put(state, :clients, Map.put(state.clients, client, new_client_data))

    # send all current clients to new client
    state.clients
    |> Enum.filter(fn {k, _v} -> k != client end)
    |> Enum.each(fn {_, data} ->
      Socket.Datagram.send(state.socket, "new_client #{data.id}", client)
    end)

    Logger.debug("Client Connected: #{inspect(client)}\nNew State: #{inspect(state)}")

    # alert existing clients of new client
    Gameserver.Socket.broadcast(
      "new_client #{new_client_data.id}",
      state.socket,
      self(),
      state.clients
    )

    {:ok, new_client_data, state}
  end

  defp update_client(state, client, data) do
    case state.clients[client] do
      nil ->
        :error

      client_data ->
        merged_data = Map.merge(client_data, data)
        {:ok, merged_data, %{state | clients: %{state.clients | client => merged_data}}}
    end
  end

  defp remove_client(state, client) do
    # TODO: handle errors
    {old_client, clients} = Map.pop(state.clients, client)
    state = %{state | clients: clients}

    Logger.debug("Client Disconnected: #{inspect(client)}\nNew State: #{inspect(state)}")

    Gameserver.Socket.broadcast(
      "remove_client #{old_client.id}",
      state.socket,
      self(),
      state.clients
    )

    {:ok, old_client, state}
  end

  defp new_bullet(state, bullet) do
    id = state.next_bullet_id
    update_bullet(Map.put(state, :next_bullet_id, id + 1), id, bullet)
  end

  defp update_bullet(state, id, bullet) do
    case state.bullets[id] do
      nil ->
        :error

      bullet_data ->
        merged_bullet_data = Map.merge(bullet_data, bullet)

        {:ok, merged_bullet_data, %{state | clients: %{state.bullets | id => merged_bullet_data}}}
    end
  end

  defp remove_bullet(state, id) do
    {removed_bullet, remaining_bullets} = Map.pop(state.bullets, id)
    {:ok, removed_bullet, %{state | bullets: remaining_bullets}}
  end

  # internal update tick stuff
  def handle_info(:update, state), do: {:noreply, game_tick(state)}

  defp schedule_update(), do: Process.send_after(self(), :update, @update_time_ms)

  defp get_dt(state) do
    now = DateTime.utc_now()
    {DateTime.diff(now, state.last_tick, :microseconds) / 1_000_000, now}
  end

  defp game_tick(state) do
    schedule_update()

    {dt, new_last_tick} = get_dt(state)

    clients = state.clients
    bullets = state.bullets

    num_clients = length(Map.keys(clients))
    num_bullets = length(Map.keys(bullets))

    state = tick_state(state, dt)

    bullets_data =
      bullets
      |> Enum.map(&Gameserver.Bullet.update_packet/1)
      |> Enum.join("\n")

    clients_data =
      clients
      |> Enum.map(&Gameserver.Client.update_packet/1)
      |> Enum.join("\n")

    payload = "up\n#{num_clients}\n#{clients_data}\n#{num_bullets}\n#{bullets_data}"

    # TODO: possibly packet IDs to prevent out-of-order errors?

    # send packet to all clients
    clients
    |> Enum.each(fn {client, _} -> Socket.Datagram.send(state.socket, payload, client) end)

    Map.put(state, :last_tick, new_last_tick)
  end

  defp tick_state(state, dt), do: state |> tick_clients(dt) |> tick_bullets(dt)

  defp tick_bullets(state, dt) do
    state.bullets
    |> Enum.reduce(state, fn c, state -> tick_bullet(c, state, dt) end)
  end

  defp tick_clients(state, dt) do
    state.clients |> Enum.reduce(state, fn c, state -> tick_client(c, state, dt) end)
  end

  defp tick_client({k, client}, state, dt) do
    # TODO: firing logic
    state |> update_client(k, Gameserver.Client.update(client, dt))
  end

  defp tick_bullet({k, bullet}, state, dt) do
    state |> update_bullet(k, Gameserver.Bullet.update(bullet, dt))
  end
end
