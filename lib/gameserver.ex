defmodule Gameserver do
  use GenServer

  @moduledoc false

  alias Gameserver.Gamestate, as: Gamestate

  require Logger

  @update_time_ms 16
  @initial_state %{
    clients: %{},
    state: Gamestate.new()
  }

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, @initial_state, name: :game)
  end

  def init(state) do
    schedule_update()
    {:ok, state}
  end

  defp schedule_update(), do: Process.send_after(self(), :update, @update_time_ms)

  def handle_info(:update, state), do: {:noreply, tick!(state)}

  def tick!(state) do
    schedule_update()

    Logger.debug(fn -> "Ticking for State: #{inspect(state)}" end)

    %{state | state: state[:state] |> tick_gamestate!()}
  end

  def tick_gamestate!(state) do
    state
    |> Gamestate.tick!()
  end

  @spec handle_call({:new_client, any}, any, map) :: {:reply, {:ok, any}, map}
  def handle_call({:new_client, client}, _from, state) do
    Logger.info("Game new_client: #{inspect(client)}")
    {:reply, {:ok, client}, %{state | clients: Map.put(state.clients, 0, client)}}
  end
end
