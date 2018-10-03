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

  @doc """
  Adapted from https://stackoverflow.com/questions/1073336/circle-line-segment-collision-detection-algorithm
  """
  def check_collide_circle(pos1, pos2, my_pos, r) do
    d1 = Graphmath.Vec2.subtract(pos2, pos1)
    d2 = Graphmath.Vec2.subtract(my_pos, pos1)
    p = Graphmath.Vec2.project(d1, d2)
    d = Graphmath.Vec2.add(pos1, p)
    f = Graphmath.Vec2.subtract(my_pos, d)
    l = Graphmath.Vec2.length(f)
    l <= r
  end
end
