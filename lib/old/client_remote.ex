defmodule Gameserver.Client.Remote do
  @type t :: {Socket.Address.t(), :inet.port_number()}
end
