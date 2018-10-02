defmodule Gameserver.Bullet do
  @enforce_keys [:pos, :vel, :lifetime, :damage]

  defstruct [:pos, :vel, :lifetime, :damage]

  def dead?(bullet) do
    bullet.lifetime <= 0
  end

  def update(bullet, dt) do
    new_pos = Graphmath.Vec2.add(bullet.pos, Graphmath.Vec2.multiply(bullet.vel, {dt, dt}))
    new_lifetime = bullet.lifetime - dt
    Map.merge(bullet, %{pos: new_pos, lifetime: new_lifetime})
  end

  def update_packet(id, bullet) do
    [
      bullet.pos |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      bullet.vel |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      id |> to_string()
    ]
    |> Enum.join(" ")
  end
end
