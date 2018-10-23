defmodule Gameserver.Application do
  use Application

  @moduledoc false

  def start(_type, _args) do
    Gameserver.Supervisor.start_link(name: Gameserver.Supervisor)
  end
end
