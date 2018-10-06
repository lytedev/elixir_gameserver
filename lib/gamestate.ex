defmodule Gameserver.Gamestate do
  alias Gameserver.Gamestate, as: Gamestate
  alias Gameserver.Client, as: Client
  alias Gameserver.Barrel, as: Barrel

  @default_map_size {4000, 4000}
  @protocol_version "0.1.5"
  @default_num_initial_barrels 200

  defstruct server_version: @protocol_version,
            last_tick: 0,
            map_size: @default_map_size,
            clients: %{},
            bullets: %{},
            barrels: %{},
            walls: %{},
            next_bullet_id: 0,
            next_barrel_id: 0

  @spec new_initial_gamestate() :: %Gamestate{}
  def new_initial_gamestate() do
    %Gameserver.Gamestate{}
    |> setup_initial_barrels(@default_num_initial_barrels)
  end

  @spec setup_initial_barrels(%Gamestate{}, num_barrels :: integer) :: %Gamestate{}
  def setup_initial_barrels(state, num_barrels) do
    {w, h} = state.map_size
    count = 0..(num_barrels - 1)

    barrels = Enum.reduce(count, %{}, fn i, b -> Map.put(b, i, Barrel.new_random(w, h)) end)

    %{state | barrels: barrels}
  end

  @spec get_client_by_id(%Gamestate{}, String.t()) :: %Client{}
  def get_client_by_id!(g, id) do
    case get_client_by_id(g, id) do
      nil -> raise ClientNotFoundError
      c -> c
    end
  end

  @spec get_client_by_id!(%Gamestate{}, String.t()) :: %Client{}
  defp get_client_by_id(state, id) do
    case Enum.filter(state.clients, fn {_, c} -> c.id == id end) do
      [{_, client}] -> client
      _ -> nil
    end
  end
end
