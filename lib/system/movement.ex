defmodule Gameserver.System.Movement do
  use ECS.System

  alias Graphmath.Vec2, as: Vec
  alias Gameserver.Component, as: Component

  def component_keys, do: [:position, :velocity]

  def perform(entity, _state, _other_entities, opts) do
    dt = opts[:dt]

    %{
      entity
      | position:
          Component.Position.new(Vec.add(entity.position.pos, Vec.scale(entity.velocity.vel, dt)))
    }
  end
end
