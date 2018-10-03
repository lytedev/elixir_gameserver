defmodule Gameserver.Bullet do
  @enforce_keys [:type, :pos, :vel, :lifetime, :damage, :owner]

  defstruct [:type, :pos, :vel, :lifetime, :damage, :owner]

  def dead?(bullet) do
    bullet.lifetime <= 0
  end

  def die(bullet) do
    Map.put(bullet, :lifetime, 0)
  end

  def update(bullet, dt) do
    new_pos = Graphmath.Vec2.add(bullet.pos, Graphmath.Vec2.multiply(bullet.vel, {dt, dt}))
    new_lifetime = bullet.lifetime - dt
    Map.merge(bullet, %{pos: new_pos, lifetime: new_lifetime})
  end

  def init_packet(id, bullet) do
    "#{bullet.owner} #{bullet.type} #{Gameserver.Bullet.update_packet(id, bullet)}"
  end

  def update_packet(id, bullet) do
    [
      bullet.pos |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      bullet.vel |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      id |> to_string()
    ]
    |> Enum.join(" ")
  end

  @doc """
  Adapted from https://stackoverflow.com/questions/1073336/circle-line-segment-collision-detection-algorithm
  """
  def check_collide_circle(bullet, new_pos, pos, r) do
    d1 = Graphmath.Vec2.subtract(new_pos, bullet.pos)
    d2 = Graphmath.Vec2.subtract(pos, bullet.pos)
    p = Graphmath.Vec2.project(d1, d2)
    d = Graphmath.Vec2.add(bullet.pos, p)
    f = Graphmath.Vec2.subtract(pos, d)
    l = Graphmath.Vec2.length(f)
    res = l <= r

    if res do
      IO.inspect(f)
      IO.inspect(l)
    end

    res
  end
end
