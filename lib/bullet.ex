defmodule Gameserver.Bullet do
  @enforce_keys [:pos, :vel, :lifetime, :damage]
  defstruct [:pos, :vel, :lifetime, :damage]

  def update(bullet, dt) do
    new_pos = Graphmath.Vec2.add(Graphmath.Vec2.multiply(bullet.vel, {dt, dt}))
    Map.put(bullet, :pos, new_pos)
  end

  def update_packet(bullet) do
    [
      bullet[:pos] |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(","),
      bullet[:id] |> to_string()
      # data[:name]
    ]
    |> Enum.join(" ")
  end
end
