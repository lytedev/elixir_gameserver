defmodule Gameserver.Client do
  # {host, port}
  @enforce_keys [:client, :id]
  @default_pos {(1280 - 32) / 2, (720 - 32) / 2}

  defstruct id: nil,
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
            active_weapon: 0,
            active_secondary_weapon: 1,
            weapons: %{
              0 => Gameserver.Weapon.cannon(),
              1 => Gameserver.Weapon.machinegun()
            },
            inputs: %{
              up: 0,
              down: 0,
              left: 0,
              right: 0,
              fire: 0,
              secondary_fire: 0
            }

  def update(client, dt) do
    # TODO: use function pattern matching instead of all this cond?
    cond do
      client.respawn_time > 0 ->
        new_client = client |> Map.put(:respawn_time, client.respawn_time - dt)

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
        |> move(dt)
    end
  end

  def set_pos(client, pos), do: Map.put(client, :pos, pos)
  def change_name(client, new_name), do: Map.put(client, :name, new_name)
  def inc_score(client), do: Map.put(client, :score, client.score + 1)
  def firing?(client), do: client.inputs.fire == 1
  def secondary_firing?(client), do: client.inputs.secondary_fire == 1
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

  @client_update_packet_regex ~r/^(\d+),(\d+),(\d+),(\d+),(\d+),(\d+) ([0-9\-\.]+),([0-9\-\.]+)/

  def parse_client_update_packet(payload) do
    p = tl(Regex.run(@client_update_packet_regex, payload))

    [up, down, left, right, fire, secondary_fire, apx, apy] =
      p |> Enum.map(&Integer.parse/1) |> Enum.map(&elem(&1, 0))

    inputs = %{
      up: up,
      down: down,
      left: left,
      right: right,
      fire: fire,
      secondary_fire: secondary_fire
    }

    {:ok, inputs, {apx, apy}}
  end

  defp move(client, dt) do
    m = Graphmath.Vec2.scale(get_movement_vector(client.inputs), client.speed * dt)
    {x, y} = Graphmath.Vec2.add(client.pos, m)
    x = min(1280 - 32, max(0, x))
    y = min(720 - 32, max(0, y))
    set_pos(client, {x, y})
  end

  defp get_movement_vector(inputs) when is_map(inputs),
    do: get_movement_vector({0 - inputs.left + inputs.right, 0 - inputs.up + inputs.down})

  defp get_movement_vector({0, 0}), do: {0, 0}
  defp get_movement_vector(m), do: Graphmath.Vec2.normalize(m)
end
