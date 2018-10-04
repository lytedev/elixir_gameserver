defmodule Gameserver.Weapon do
  alias Graphmath.Vec2, as: Vec

  defstruct name: "Cannon",
            fire_rate: 0.4,
            bullet_spawn_offset: 0.08,
            bullet_speed: 500,
            bullet_lifetime: 5,
            bullet_damage: 10,
            cooldown: 0

  def update(weapon, dt) do
    Map.put(weapon, :cooldown, max(0, weapon.cooldown - dt))
  end

  def fired(weapon) do
    Map.put(weapon, :cooldown, weapon.fire_rate)
  end

  def can_fire?(weapon) do
    weapon.cooldown <= 0
  end

  def generate_bullet(weapon, pos, direction, owner, offset \\ nil) do
    vel = direction |> Vec.normalize() |> Vec.scale(weapon.bullet_speed)

    case weapon.bullet_spawn_offset do
      {x, y} ->
        {dx, dy} = direction

        alt_generate_bullet(
          weapon,
          Vec.add(pos, Vec.rotate({x, y}, Math.atan2(dy, dx))),
          owner,
          vel
        )

      x ->
        alt_generate_bullet(weapon, Vec.add(pos, Vec.scale(vel, x)), owner, vel)
    end
  end

  defp alt_generate_bullet(weapon, pos, owner, vel) do
    %Gameserver.Bullet{
      owner: owner,
      type: String.downcase(weapon.name),
      pos: pos,
      vel: vel,
      lifetime: weapon.bullet_lifetime,
      damage: weapon.bullet_damage
    }
  end
end
