defmodule Gameserver.Weapon do
  defstruct name: "Cannon",
            type: 0,
            fire_rate: 0.4,
            damage: 35,
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

  def generate_bullet(weapon, pos, direction) do
    %Gameserver.Bullet{
      pos: pos,
      vel: direction |> Graphmath.Vec2.normalize() |> Graphmath.Vec2.scale(weapon.bullet_speed),
      lifetime: weapon.bullet_lifetime,
      damage: weapon.damage
    }
  end
end
