defmodule Gameserver.Client do
  # {host, port}
  @enforce_keys [:client, :id]
  defstruct id: nil,
            client: nil,
            name: "Player",
            color: {1.0, 1.0, 1.0, 1.0},
            score: 0,
            pos: {(1280 - 32) / 2, (720 - 32) / 2},
            aimpos: {0, 0},
            size: {32, 32},
            speed: 100,
            health: 100,
            max_health: 100,
            active_weapon: 0,
            weapons: %{
              0 => %Gameserver.Weapon{}
            },
            inputs: %{
              up: 0,
              down: 0,
              left: 0,
              right: 0,
              fire: 0
            }

  def update(client, dt) do
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

  def change_name(client, new_name), do: Map.put(client, :name, new_name)
  def firing?(client), do: client.inputs.fire == 1
  def active_weapon(client), do: client.weapons[client.active_weapon]

  def update_weapon(client, weapon_id, weapon) do
    Map.put(client, :weapons, Map.put(client.weapons, weapon_id, weapon))
  end

  def update_packet(client) do
    [
      client.size |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      client.color |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      client.pos |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      client.aimpos |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      (client.health / client.max_health) |> to_string(),
      client.score |> to_string(),
      client.id
      # client.name
    ]
    |> Enum.join(" ")
  end

  @client_update_packet_regex ~r/^(\d+),(\d+),(\d+),(\d+),(\d+) ([0-9\-\.]+),([0-9\-\.]+)/

  def parse_client_update_packet(payload) do
    p = tl(Regex.run(@client_update_packet_regex, payload))

    [up, down, left, right, fire, apx, apy] =
      p |> Enum.map(&Integer.parse/1) |> Enum.map(&elem(&1, 0))

    inputs = %{
      up: up,
      down: down,
      left: left,
      right: right,
      fire: fire
    }

    {:ok, inputs, {apx, apy}}
  end

  defp move(client, dt) do
    m = Graphmath.Vec2.scale(get_movement_vector(client.inputs), client.speed * dt)
    new_pos = Graphmath.Vec2.add(client.pos, m)
    Map.put(client, :pos, new_pos)
  end

  defp get_movement_vector(inputs) when is_map(inputs),
    do: get_movement_vector({0 - inputs.left + inputs.right, 0 - inputs.up + inputs.down})

  defp get_movement_vector({0, 0}), do: {0, 0}
  defp get_movement_vector(m), do: Graphmath.Vec2.normalize(m)
end
