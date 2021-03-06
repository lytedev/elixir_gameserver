defmodule Gameserver.Client do
  alias Graphmath.Vec2, as: Vec

  @enforce_keys [:client, :id]
  @default_pos {0, 0}
  @client_update_packet_regex ~r/^(\d+),(\d+),(\d+),(\d+),(\d+),(\d+) ([0-9\-\.]+),([0-9\-\.]+) (\d+) (\d+)/

  defstruct id: nil,
            # {host, post}
            # example: {{127, 0, 0, 1}, 58527}
            client: nil,
            name: "Player",
            color: {1.0, 1.0, 1.0, 1.0},
            score: 0,
            pos: @default_pos,
            aimpos: {0, 0},
            size: {32, 32},
            speed: 100,
            health: 100,
            max_health: 100,
            respawn_time: 0,
            since_last_update: 0,
            active_weapon: 0,
            active_secondary_weapon: 2,
            weapons: %{
              0 => Gameserver.Weapons.cannon(),
              1 => Gameserver.Weapons.machinegun(),
              2 => Gameserver.Weapons.minelayer()
            },
            inputs: %{
              up: 0,
              down: 0,
              left: 0,
              right: 0,
              fire: 0,
              secondary_fire: 0
            }

  def update(client, dt, map_size) do
    # TODO: use function pattern matching instead of all this cond?
    cond do
      dead?(client) ->
        new_client =
          client
          |> Map.put(:respawn_time, client.respawn_time - dt)

        cond do
          new_client.respawn_time <= 0 ->
            new_client
            |> Map.put(:respawn_time, 0)
            |> Map.put(:health, new_client.max_health)
            |> Map.put(:pos, @default_pos)

          true ->
            new_client
        end

      client.health <= 0 ->
        client
        |> Map.put(:health, client.max_health)
        |> Map.put(:respawn_time, 5)

      true ->
        Map.put(
          client,
          :weapons,
          client.weapons
          |> Enum.reduce(%{}, fn {id, weapon}, weapons ->
            Map.put(weapons, id, Gameserver.Weapon.update(weapon, dt))
          end)
        )
        |> move(dt, map_size)
    end
    |> Map.put(:since_last_update, client.since_last_update + dt)
  end

  def dead?(client), do: client.respawn_time > 0
  def set_pos(client, pos), do: Map.put(client, :pos, pos)
  def change_name(client, new_name), do: Map.put(client, :name, new_name)
  def inc_score(client), do: Map.put(client, :score, client.score + 1)
  def firing?(client), do: client.inputs.fire == 1 && not dead?(client)
  def secondary_firing?(client), do: client.inputs.secondary_fire == 1 && not dead?(client)
  def active_weapon(client), do: client.weapons[client.active_weapon]
  def active_secondary_weapon(client), do: client.weapons[client.active_secondary_weapon]

  def damage(client, damage) do
    Map.put(client, :health, max(0, min(client.max_health, client.health - damage)))
  end

  def update_weapon(client, weapon_id, weapon) do
    Map.put(client, :weapons, Map.put(client.weapons, weapon_id, weapon))
  end

  def update_packet(client) do
    active_weapon = active_weapon(client)
    active_secondary_weapon = active_secondary_weapon(client)

    [
      client.size |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      client.color |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      client.pos |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      client.aimpos |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      (active_weapon.cooldown / active_weapon.fire_rate) |> to_string(),
      (active_secondary_weapon.cooldown / active_secondary_weapon.fire_rate) |> to_string(),
      (client.health / client.max_health) |> to_string(),
      client.score |> to_string(),
      client.respawn_time |> to_string(),
      client.id
      # client.name
    ]
    |> Enum.join(" ")
  end

  def parse_client_update_packet(payload) do
    p = tl(Regex.run(@client_update_packet_regex, payload))

    [
      up,
      down,
      left,
      right,
      fire,
      secondary_fire,
      apx,
      apy,
      active_weapon,
      active_secondary_weapon
    ] = p |> Enum.map(&Integer.parse/1) |> Enum.map(&elem(&1, 0))

    inputs = %{
      up: up,
      down: down,
      left: left,
      right: right,
      fire: fire,
      secondary_fire: secondary_fire
    }

    {:ok, inputs, {apx, apy}, active_weapon, active_secondary_weapon}
  end

  defp move(client, dt, {w, h}) do
    m = Vec.scale(get_movement_vector(client.inputs), client.speed * dt)
    {x, y} = Vec.add(client.pos, m)
    {cw, ch} = client.size
    x = min(w / 2 - cw / 2, max(-w / 2 + cw / 2, x))
    y = min(h / 2 - ch / 2, max(-h / 2 + ch / 2, y))
    set_pos(client, {x, y})
  end

  defp get_movement_vector(inputs) when is_map(inputs),
    do: get_movement_vector({0 - inputs.left + inputs.right, 0 - inputs.up + inputs.down})

  defp get_movement_vector({0, 0}), do: {0, 0}
  defp get_movement_vector(m), do: Vec.normalize(m)
end
