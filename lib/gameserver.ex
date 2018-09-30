defmodule Gameserver do
  require Logger
  use GenServer

  # TODO: cleanup clients that haven't sent data in some time
  # TODO: handle crashes gracefully with regards to connected clients

  @default_port 6090
  @update_time_ms 16

  @initial_state %{
    last_tick: 0,
    clients: %{}
  }

  def init(state) do
    # start a socket for network interactions
    # TODO: supervised, so it can restart without restarting the game
    port = state[:port] || @default_port
    {:ok, socket} = Socket.UDP.open(port)
    Task.start_link(Gameserver.Socket, :start, [%{socket: socket, game: self(), port: port}])
    # begin running game updates
    schedule_update()
    Logger.debug("Game Process init() Complete: (Self: #{inspect(self())}")
    state = %{state | last_tick: DateTime.utc_now()}
    {:ok, Map.put(state, :socket, socket)}
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, @initial_state)
  end

  # internal helpers
  def call_get_all_clients(game) do
    GenServer.call(game, :get_all_clients)
  end

  def call_new_client(game, client) do
    GenServer.call(game, {:new_client, client})
  end

  def call_remove_client(game, client) do
    GenServer.call(game, {:remove_client, client})
  end

  def call_update_client(game, {client, data}) do
    GenServer.call(game, {:update_client, client, data})
  end

  # genserver callbacks
  def handle_call(:get_all_clients, _from, state), do: {:reply, {:ok, state[:clients]}, state}

  def handle_call({:new_client, client}, _from, state) do
    # TODO: handle errors
    case new_client(state, client) do
      {:ok, reply, new_state} -> {:reply, {:ok, reply}, new_state}
      _ -> {:reply, :error, state}
    end
  end

  # TODO: handle errors
  def handle_call({:remove_client, client}, _from, state) do
    case remove_client(state, client) do
      {:ok, reply, new_state} -> {:reply, {:ok, reply}, new_state}
      _ -> {:reply, :error, state}
    end
  end

  def handle_call({:update_client, client, data}, _from, state) do
    # TODO: handle errors
    case update_client(state, client, data) do
      {:ok, reply, new_state} ->
        {:reply, {:ok, reply}, new_state}

      _ ->
        Socket.Datagram.send(state[:socket], "disconnected client_not_found", client)
        {:reply, :error, state}
    end
  end

  # mutations
  defp new_client(state, client) do
    # TODO: handle errors
    client_content = %{
      client: client,
      # TODO: handle duplicates
      id: :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32),
      color: {0.0, 0.5, 1.0, 1.0},
      score: 0,
      pos: {0, 0},
      size: {32, 32},
      speed: 500,
      aimpos: {0, 0},
      inputs: %{
        up: 0,
        down: 0,
        left: 0,
        right: 0,
        fire: 0
      },
      name: "Player"
    }

    {:ok, client_content,
     %{
       state
       | clients:
           state[:clients]
           |> Map.put(client, client_content)
     }}
  end

  defp remove_client(state, client) do
    # TODO: handle errors
    {old_client, clients} = state[:clients] |> Map.pop(client)
    {:ok, old_client, %{state | clients: clients}}
  end

  defp update_client(state, client, data) do
    # TODO: handle errors
    # Logger.info("Client Update: #{inspect(client)} #{inspect(data)}\nState: #{inspect(state)}")

    case state[:clients][client] do
      nil ->
        :error

      client_data ->
        new_client_data = Map.merge(client_data, data)
        {:ok, client_data, %{state | clients: %{state[:clients] | client => new_client_data}}}
    end
  end

  # internal update tick stuff
  def handle_info(:update, state) do
    # TODO: internal only?
    {:noreply, game_tick(state)}
  end

  defp schedule_update() do
    # 16 ms ~= 60 UPS
    Process.send_after(self(), :update, @update_time_ms)
  end

  defp game_tick(state) do
    schedule_update()

    tick = DateTime.utc_now()
    dt = DateTime.diff(tick, state[:last_tick], :microseconds) / 1_000_000
    # Logger.info(inspect(dt))

    clients = state[:clients]
    num_clients = length(Map.keys(clients))
    # num_clients = length(Map.keys(clients))

    state = tick_state(state, dt)

    clients_data =
      clients
      |> Enum.map(&client_update_string/1)
      |> Enum.join("\n")

    payload = "up #{num_clients}\n#{clients_data}"

    broadcast = fn client ->
      Socket.Datagram.send(state[:socket], payload, client[:client])
    end

    clients |> Enum.each(&broadcast.(elem(&1, 1)))
    %{state | last_tick: tick}
  end

  defp client_update_string(client) do
    # TODO: possibly packet IDs to prevent out-of-order errors?
    data = elem(client, 1)

    [
      data[:size] |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      data[:color] |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      data[:pos] |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      data[:aimpos] |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      data[:score] |> to_string(),
      data[:id]
      # data[:name]
    ]
    |> Enum.join(" ")
  end

  defp tick_state(state, dt), do: %{state | clients: tick_clients(state[:clients], dt)}

  defp tick_clients(clients, dt),
    do: clients |> Enum.reduce(clients, fn e, acc -> tick_client(e, acc, dt) end)

  defp tick_client({k, client}, clients, dt) do
    inputs = client[:inputs]
    speed = client[:speed]
    mx = -inputs[:left] + inputs[:right]
    my = -inputs[:up] + inputs[:down]
    {x, y} = client[:pos]
    # TODO: vector library?
    %{clients | k => %{client | pos: {x + mx * speed * dt, y + my * speed * dt}}}
  end
end
