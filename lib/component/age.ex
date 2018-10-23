defmodule Gameserver.Component.Age do
  defstruct current_age: 0, max_age: 0

  @spec new(current_age :: number, max_age :: number) :: map
  def new(current_age \\ 0, max_age \\ 0) when is_number(current_age) and is_number(max_age) do
    %__MODULE__{
      current_age: current_age,
      max_age: max_age
    }
  end

  def elapse(age, dt) do
    age
    |> set(age.current_age + dt)
  end

  def set(age, new_age) do
    %{age | current_age: new_age}
  end

  def dead?(age) do
    age.current_age >= age.max_age && age.max_age > 0
  end
end
