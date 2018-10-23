defmodule Gameserver.Gamestate do
  alias Gameserver.Gamestate, as: Gamestate
  alias Gameserver.System, as: GameSystem
  alias Gameserver.Player, as: Player

  @default_map_size {4000, 4000}
  @default_num_initial_barrels 200

  defstruct last_tick: DateTime.utc_now(),
            map_size: @default_map_size,
            entities: [],
            systems: []

  # init

  @spec new(Keyword.t()) :: %Gamestate{}
  def new(opts \\ []) do
    %__MODULE__{
      last_tick: DateTime.utc_now(),
      systems: [
        GameSystem.NetTick,
        GameSystem.Age,
        GameSystem.Movement
      ]
    }
    |> setup_initial_entities!(opts)
    |> IO.inspect()
  end

  @spec setup_initial_entities!(%Gamestate{}, Keyword.t()) :: %Gamestate{}
  def setup_initial_entities!(state, opts) do
    # add barrels
    num_barrels = opts[:num_initial_barrels] || @default_num_initial_barrels
    # count = 0..(num_barrels - 1)
    # barrels = Enum.reduce(count, %{}, fn i, b -> Map.put(b, i, Barrel.new_random(w, h)) end)

    entities = [Player.new()]

    map_size = opts[:map_size] || @default_map_size

    %{state | map_size: map_size, entities: entities}
  end

  @spec tick!(%Gamestate{}) :: %Gamestate{}
  def tick!(gamestate) do
    {dt, last_tick} = get_delta_time_now(gamestate)

    gamestate
    |> run_systems!(dt)
    |> update_last_tick(last_tick)
  end

  defp run_systems!(gamestate, dt) do
    {entities, _} = ECS.System.run(gamestate.systems, gamestate.entities, dt: dt)
    %{gamestate | entities: entities}
  end

  @spec update_last_tick(%Gamestate{}, %DateTime{}) :: %Gamestate{}
  defp update_last_tick(gamestate, time) do
    %{gamestate | last_tick: time}
  end

  # mutation helpers

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
end
