defmodule Gameserver.System.NetTick do
  use ECS.System

  alias Graphmath.Vec2, as: Vec
  alias Gameserver.Component, as: Component

  def component_keys, do: [:position, :vel]

  def perform(entity, _state, _other_entities, opts) do
    # TODO: boil entity's components down to packets and broadcast
  end
end
