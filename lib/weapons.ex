defmodule Gameserver.Weapons do
  alias Gameserver.Weapon

  def cannon() do
    %Weapon{
      name: "Cannon",
      fire_rate: 0.4,
      bullet_spawn_offset: 0.06,
      bullet_speed: 500,
      bullet_lifetime: 3,
      bullet_damage: 20,
      cooldown: 0
    }
  end

  def machinegun() do
    %Weapon{
      name: "Machinegun",
      fire_rate: 0.05,
      bullet_spawn_offset: 0.035,
      bullet_speed: 1500,
      bullet_lifetime: 0.25,
      bullet_damage: 2,
      cooldown: 0
    }
  end

  def minelayer() do
    %Weapon{
      name: "Minelayer",
      fire_rate: 5.0,
      bullet_spawn_offset: {32, 0},
      bullet_speed: 0,
      bullet_lifetime: 10,
      bullet_damage: 40,
      cooldown: 0
    }
  end
end
