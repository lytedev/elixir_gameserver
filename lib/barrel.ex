defmodule Gameserver.Barrel do
  @enforce_keys [:pos]

  defstruct pos: nil,
            color: {1, 1, 1, 1},
            health: 100_000,
            size: {24, 24}

  def dead?(barrel) do
    barrel.health <= 0
  end

  def damage(barrel, dmg) do
    Map.put(barrel, :health, barrel.health - dmg)
  end

  def die(barrel) do
    Map.put(barrel, :health, 0)
  end

  def init_packet(id, barrel) do
    [
      barrel.pos |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      barrel.color |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      barrel.size |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      barrel.health |> to_string(),
      id |> to_string()
    ]
    |> Enum.join(" ")
  end

  def check_collide_circle(pos1, pos2, my_pos, r) do
    Gameserver.Physics.line_segment_collides_circle?(pos1, pos2, my_pos, r)
  end
end
