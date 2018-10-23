defmodule Gameserver.Component.Velocity do
  @spec new({number, number}) :: map
  def new({x, y}) when is_number(x) and is_number(y), do: %{vel: {x, y}}

  @spec new(number | nil, number | nil) :: map
  def new(x \\ 0, y \\ 0) when is_number(x) and is_number(y), do: new({x, y})
end
