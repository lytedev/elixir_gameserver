defmodule Gameserver.Gamestate do
  alias Gameserver.Gamestate, as: Gamestate
  alias Gameserver.Client, as: Client
  alias Gameserver.Barrel, as: Barrel

  @default_map_size {4000, 4000}
  @protocol_version "0.1.5"
  @default_num_initial_barrels 200

  defstruct server_version: @protocol_version,
            last_tick: DateTime.utc_now(),
            map_size: @default_map_size,
            clients: %{},
            bullets: %{},
            barrels: %{},
            walls: %{},
            next_bullet_id: 0,
            next_barrel_id: 0

  # init

  @spec init() :: %Gamestate{}
  def init() do
    %Gameserver.Gamestate{}
    |> Map.put(:last_tick, DateTime.utc_now())
    |> setup_initial_barrels!(@default_num_initial_barrels)
  end

  @spec setup_initial_barrels!(%Gamestate{}, num_barrels :: integer) :: %Gamestate{}
  def setup_initial_barrels!(state, num_barrels) do
    {w, h} = state.map_size
    count = 0..(num_barrels - 1)
    barrels = Enum.reduce(count, %{}, fn i, b -> Map.put(b, i, Barrel.new_random(w, h)) end)
    %{state | barrels: barrels}
  end

  # mutations

  # network

  @spec update_last_tick(%Gamestate{}, %DateTime{}) :: %Gamestate{}
  defp update_last_tick(gamestate, time) do
    %{gamestate | last_tick: time}
  end

  @spec add_new_client!(%Gamestate{}, Client.Remote.t(), player_name :: String.t()) ::
          %Gamestate{}
  defp add_new_client!(gamestate, remote, name) do
    %{gamestate | clients: Map.put(gamestate.clients, remote, Client.init(remote, name))}
  end

  @spec update_client!(%Gamestate{}, Client.Remote.t(), %Client{}) :: %Gamestate{}
  defp update_client!(gamestate, client_remote, client) do
    %{gamestate | clients: %{gamestate.clients | client_remote => client}}
  end

  @spec merge_client!(%Gamestate{}, Client.Remote.t(), %Client{}) :: %Gamestate{}
  defp update_client!(gamestate, client_remote, client) do
    %{
      gamestate
      | clients: %{
          gamestate.clients
          | client_remote => Map.merge(gamestate.clients[client_remote], client)
        }
    }
  end

  @spec remove_client!(%Gamestate{}, Client.Remote.t()) :: %Gamestate{}
  defp remove_client!(gamestate, remote) do
    %{gamestate | clients: Map.delete(gamestate.clients, remote)}
  end

  # internal

  @spec tick!(%Gamestate{}) :: %Gamestate{}
  defp tick!(gamestate) do
    {dt, last_tick} = get_delta_time_now(gamestate)

    gamestate
    |> update_last_tick(last_tick)
    |> tick_clients!(dt)
    |> tick_bullets!(dt)
  end

  # mutation helpers

  @spec fire_client!(%Gamestate{}, Client.Remote.t(), bullet_id :: integer) :: %Gamestate{}
  defp fire_client!(gamestate, client_remote, bullet_id) do
    gamestate
  end

  @spec remove_bullet!(%Gamestate{}, bullet_id :: integer) :: %Gamestate{}
  defp remove_bullet!(gamestate, bullet_id) do
    gamestate
  end

  @spec bullet_hit_client!(%Gamestate{}, bullet_id :: integer, Client.Remote.t()) :: %Gamestate{}
  defp bullet_hit_client!(gamestate, bullet_id, client_remote) do
    gamestate
  end

  @spec client_move!(%Gamestate{}, bullet_it :: integer, Client.Remote.t()) :: %Gamestate{}
  defp client_move!(gamestate, bullet_id, client_remote) do
    gamestate
  end

  @spec tick_client!(%Gamestate{}, Client.Remote.t(), dt :: float) :: %Gamestate{}
  defp tick_client!(gamestate, client_remote, dt) do
    update_client = Client.tick!(Gamestate.get_client_by_id!(client_remote), dt)
  end

  @spec tick_bullet!(%Gamestate{}, bullet_id :: integer, dt :: float) :: %Gamestate{}
  defp tick_bullet!(gamestate, bullet_id, dt) do
    gamestate
  end

  @spec tick_clients!(%Gamestate{}, dt :: float) :: %Gamestate{}
  defp tick_clients!(gamestate, dt) do
    tick_entity_map!(gamestate, :clients, &tick_client!/3, dt)
  end

  @spec tick_bullets!(%Gamestate{}, dt :: float) :: %Gamestate{}
  defp tick_bullets!(gamestate, dt) do
    tick_entity_map!(gamestate, :bullets, &tick_bullet!/3, dt)
  end

  @spec tick_entity_map!(
          %Gamestate{},
          atom,
          (%Gamestate{}, any, float -> %Gamestate{}),
          dt :: float
        ) :: %Gamestate{}
  defp tick_entity_map!(gamestate, key, callback, dt) do
    MapUtils.reduce_child_map!(gamestate, key, callback, dt)
  end

  @spec merge_entity!(%Gamestate{}, entity_map_key :: atom, entity_key :: key, entity :: any) ::
          %Gamestate{}
  def merge_entity!(gamestate, entity_map_key, entity_key, entity) do
    %{
      gamestate
      | entity_map_key => %{
          gamestate[entity_map_key]
          | entity_key => Map.merge(gamestate[entity_map_key][entity_key], entity)
        }
    }
  end

  @spec merge_entity!(%Gamestate{}, entity_map_key :: atom, entity_key :: key, entity :: any) ::
          %Gamestate{}
  def merge_entity!(gamestate, entity_map_key, entity_key, entity) do
    %{
      gamestate
      | entity_map_key => %{
          gamestate[entity_map_key]
          | entity_key => Map.merge(gamestate[entity_map_key][entity_key], entity)
        }
    }
  end

  # getters

  @spec get_delta_time(%Gamestate{}, current_time :: float) :: float
  def get_delta_time(gamestate, current_time \\ nil)

  def get_delta_time(gamestate, nil) do
    get_delta_time(gamestate, DateTime.utc_now())
  end

  def get_delta_time(gamestate, current_time) do
    DateTime.diff(current_time, gamestate.last_tick, :microseconds) / 1_000_000
  end

  @spec get_delta_time_now(%Gamestate{}) :: {dt :: float, current_time :: %DateTime{}}
  def get_delta_time_now(gamestate) do
    now = DateTime.utc_now()
    {get_delta_time(gamestate, now), now}
  end

  @spec get_client_by_id(%Gamestate{}, String.t()) :: %Client{}
  def get_client_by_id(state, id) do
    case Enum.filter(state.clients, fn {_, c} -> c.id == id end) do
      [{_, client}] -> client
      _ -> nil
    end
  end

  @spec get_client_by_id!(%Gamestate{}, String.t()) :: %Client{}
  def get_client_by_id!(g, id) do
    case get_client_by_id(g, id) do
      nil -> raise ClientNotFoundError
      c -> c
    end
  end
end
