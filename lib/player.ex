defmodule Gameserver.Client do
  # {host, port}
  @enforce_keys [:client]
  defstruct id: :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32),
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
    move(client[:inputs])
  end

  def firing?(client), do: client[:inputs][:fire] == 1
  def active_weapon(client), do: client[:weapons][client[:active_weapon]]

  def update_packet(client) do
    [
      client[:size] |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      client[:color] |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      client[:pos] |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      client[:aimpos] |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      (client[:health] / client[:max_health]) |> to_string(),
      client[:score] |> to_string(),
      client[:id]
      # client[:name]
    ]
    |> Enum.join(" ")
  end

  def parse_client_update_packet(update_data_string) do
    [raw_inputs, raw_aimpos] = String.split(update_data_string, " ")

    to_integer_list = fn e ->
      String.split(e, ",")
      |> Enum.map(&Integer.parse/1)
      |> Enum.map(&elem(&1, 0))
    end

    input_zipper = fn l ->
      Enum.zip([:up, :down, :left, :right, :fire], l)
      |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, k, v) end)
    end

    inputs =
      raw_inputs
      |> to_integer_list.()
      |> Enum.map(
        &case &1 do
          0 -> 0
          _ -> 1
        end
      )
      |> input_zipper.()

    aimpos = raw_aimpos |> to_integer_list.() |> List.to_tuple()

    {:ok, inputs, aimpos}
  end

  defp move(inputs) do
    m = Graphmath.Vec2.scale(get_movement_vector(inputs), client[:speed] * dt)
    new_pos = Graphmath.Vec2.add(client[:pos], m)
    Map.put(client, :pos, new_pos)
  end

  defp get_movement_vector(inputs) when is_map(inputs),
    do: get_movement_vector({0 - inputs[:left] + inputs[:right], 0 - inputs[:up] + inputs[:down]})

  defp get_movement_vector({0, 0}), do: {0, 0}
  defp get_movement_vector(m), do: Graphmath.Vec2.normalize(m)
end
