defmodule Gameserver.Player do
  alias ECS.Entity, as: Entity

  alias Gameserver.Component, as: Component

  def new() do
    Entity.new([
      Component.Age.new(),
      Component.Position.new(),
      Component.Velocity.new(10, 10)
    ])
  end
end
