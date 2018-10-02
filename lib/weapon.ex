defmodule Gameserver.Weapon do
  defstruct name: "Cannon",
            type: 0,
            fire_rate: 0.4,
            bullet_speed: 500,
            bullet_lifetime: 5000,
            bullet_damage: 10,
            cooldown: 0

  def generate_bullet(weapon, pos, direction) do
    %Gameserver.Bullet{
      pos: pos,
      vel: direction |> Graphmath.Vec2.normalize() |> Graphmath.Vec2.scale(weapon.bullet_speed),
      lifetime: weapon.bullet_lifetime,
      damage: weapon.damage
    }
  end
end
