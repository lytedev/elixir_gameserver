defmodule Gameserver.Bullet do
  alias Graphmath.Vec2, as: Vec

  @enforce_keys [:type, :pos, :vel, :lifetime, :damage, :owner]
  @new_packet_prefix "new_bullet"

  defstruct [:type, :pos, :vel, :lifetime, :damage, :owner]

  def dead?(bullet) do
    bullet.lifetime <= 0
  end

  def die(bullet) do
    Map.put(bullet, :lifetime, 0)
  end

  def update(bullet, dt) do
    new_pos = Vec.add(bullet.pos, Vec.multiply(bullet.vel, {dt, dt}))
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

  def check_collide_circle(bullet, new_pos, pos, r) do
    Gameserver.Physics.line_segment_collides_circle?(bullet.pos, new_pos, pos, r)
  end
end
