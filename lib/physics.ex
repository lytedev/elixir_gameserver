defmodule Gameserver.Physics do
  alias Graphmath.Vec2, as: Vec

  @doc """
  Adapted from https://stackoverflow.com/questions/1073336/circle-line-segment-collision-detection-algorithm
  """
  def line_segment_collides_circle?(segment_start_pos, segment_end_pos, circle_pos, radius) do
    d1 = Vec.subtract(segment_end_pos, segment_start_pos)
    d2 = Vec.subtract(circle_pos, segment_start_pos)
    p = Vec.project(d1, d2)
    d = Vec.add(segment_start_pos, p)
    f = Vec.subtract(circle_pos, d)
    Vec.length(f) <= radius
  end
end
