defmodule Gameserver.Component.Position do
  defstruct pos: {0, 0}

  @spec new({number, number}) :: map
  def new({x, y}) when is_number(x) and is_number(y), do: %__MODULE__{pos: {x, y}}

  @spec new(number | nil, number | nil) :: map
  def new(x \\ 0, y \\ 0) when is_number(x) and is_number(y), do: new({x, y})
end
