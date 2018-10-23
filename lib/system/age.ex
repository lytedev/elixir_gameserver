defmodule Gameserver.System.Age do
  use ECS.System

  alias Graphmath.Vec2, as: Vec
  alias Gameserver.Component, as: Component

  def component_keys, do: [:age]

  def perform(entity, _state, _other_entities, opts) do
    dt = opts[:dt]

    %{
      entity
      | age: Component.Age.elapse(entity.age, dt)
    }
  end
end
