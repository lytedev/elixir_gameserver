defmodule Gameserver.Weapon do
  defstruct name: "Cannon",
            type: 0,
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

  def generate_bullet(weapon, pos, direction, owner) do
    vel = direction |> Graphmath.Vec2.normalize() |> Graphmath.Vec2.scale(weapon.bullet_speed)

    %Gameserver.Bullet{
      owner: owner,
      type: String.downcase(weapon.name),
      pos: Graphmath.Vec2.add(pos, Graphmath.Vec2.scale(vel, weapon.bullet_spawn_offset)),
      vel: vel,
      lifetime: weapon.bullet_lifetime,
      damage: weapon.bullet_damage
    }
  end

  def cannon() do
    %Gameserver.Weapon{
      name: "Cannon",
      type: 0,
      fire_rate: 0.4,
      bullet_spawn_offset: 0.06,
      bullet_speed: 500,
      bullet_lifetime: 3,
      bullet_damage: 10,
      cooldown: 0
    }
  end

  def machinegun() do
    %Gameserver.Weapon{
      name: "Machinegun",
      type: 1,
      fire_rate: 0.05,
      bullet_spawn_offset: 0.025,
      bullet_speed: 1500,
      bullet_lifetime: 0.25,
      bullet_damage: 3,
      cooldown: 0
    }
  end
end
