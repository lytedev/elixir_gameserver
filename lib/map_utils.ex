defmodule MapUtils do
  @spec reduce_child_map!(map, any, (map, any, any -> map), args :: any) :: map
  defp reduce_child_map!(map, key, callback, args) do
    Enum.reduce(map[key], map, fn {k, _v}, map ->
      callback.(map, key, args)
    end)
  end
end
