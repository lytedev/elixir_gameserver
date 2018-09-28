defmodule Gameserver do
  require Logger
  use GenServer

  @initial_state %{
    clients: %{}
  }

  @update_time_ms 16

  def init(state) do
    # start a socket for network interactions
    # TODO: supervised, so it can restart without restarting the game
    Task.start_link(Gameserver.Socket, :start, [%{game: self()}])
    # begin running game updates
    schedule_update()
    Logger.debug("Game Process init() Complete: (Self: #{inspect(self())}")
    {:ok, state}
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

  def handle_call({:remove_client, client}, _from, state) do
    # TODO: handle errors
    case remove_client(state, client) do
      {:ok, reply, new_state} -> {:reply, {:ok, reply}, new_state}
      _ -> {:reply, :error, state}
    end
  end

  def handle_call({:update_client, client, data}, _from, state) do
    # TODO: handle errors
    case update_client(state, client, data) do
      {:ok, reply, new_state} -> {:reply, {:ok, reply}, new_state}
      _ -> {:reply, :error, state}
    end
  end

  # mutations
  defp new_client(state, client) do
    # TODO: handle errors
    client_content = %{
      client: client,
      id: :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32),
      color: {0.0, 0.5, 1.0, 1.0},
      pos: {0, 0},
      aimpos: {0, 0},
      inputs: %{
        up: 0,
        down: 0,
        left: 0,
        right: 0,
        fire: 0
      },
      name: ""
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
    client_data = Map.merge(state[:clients][client], data)
    {:ok, client_data, %{state | clients: %{state[:clients] | client => client_data}}}
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
    # Logger.debug("TICK")
    state
  end
end
