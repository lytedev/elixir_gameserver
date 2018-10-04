defmodule Gameserver do
  require Logger
  use GenServer

  @default_port 6090
  @update_time_ms 16
  @num_barrels 100

  @initial_state %{
    server_version: "0.1.5", # TODO: get from mix version
    last_tick: 0,
    map_size: {2000, 2000},
    clients: %{},
    bullets: %{},
    barrels: %{},
    next_bullet_id: 0,
    next_barrel_id: 0
  }

  def init(state) do
    schedule_update()
    {:ok, socket, _pid} = open_socket(state)

    Logger.debug("Game Process init() Complete: (Self: #{inspect(self())}")

    {:ok, Map.merge(state, %{last_tick: DateTime.utc_now(), socket: socket})}
  end

  def open_socket(state) do
    # TODO: supervised, so the socket can restart without restarting the entire
    # game
    # start a socket for network interactions
    port = state[:port] || @default_port
    {:ok, socket} = Socket.UDP.open(port)

    {:ok, pid} =
      Task.start_link(Gameserver.Socket, :start, [
        %{socket: socket, game: self(), port: port, server_version: state.server_version}
      ])

    {:ok, socket, pid}
  end

  def start_link(_opts), do: GenServer.start_link(__MODULE__, generate_barrels(@initial_state))

  defp generate_barrels(state) do
    {w, h} = state.map_size

    Map.put(
      state,
      :barrels,
      Enum.reduce(0..(@num_barrels - 1), %{}, fn id, barrels ->
        Map.put(barrels, id, %Gameserver.Barrel{
          pos: {:rand.uniform(w) - w / 2, :rand.uniform(w) - w / 2}
        })
      end)
    )
  end

  # internal helpers
  def call_get_all_clients(game), do: GenServer.call(game, :get_all_clients)
  def call_new_client(game, client, opts), do: GenServer.call(game, {:new_client, client, opts})
  def call_remove_client(game, client), do: GenServer.call(game, {:remove_client, client})

  def call_update_client(game, {client, data}),
    do: GenServer.call(game, {:update_client, client, data})

  def call_update_client_name(game, client, name),
    do: GenServer.call(game, {:update_client, Gameserver.Client.change_name(client, name)})

  # TODO: handle errors
  defp handle_call_wrapper(res, error_callback \\ fn x -> x end)

  defp handle_call_wrapper({:ok, reply, state}, _error_callback),
    do: {:reply, {:ok, reply}, state}

  defp handle_call_wrapper({_, _reply, state}, error_callback),
    do: {:reply, :error, state} |> error_callback.()

  # genserver callbacks
  def handle_call(:get_all_clients, _from, state), do: {:reply, {:ok, state.clients}, state}

  def handle_call({:new_client, client, opts}, _from, state),
    do: handle_call_wrapper(new_client(state, client, opts))

  def handle_call({:remove_client, client}, _from, state) do
    handle_call_wrapper(remove_client(state, client), fn x ->
      Socket.Datagram.send(state.socket, "disconnected client_not_found", client)
      x
    end)
  end

  def handle_call({:update_client, client, data}, _from, state) do
    handle_call_wrapper(update_client(state, client, data), fn x ->
      Socket.Datagram.send(state.socket, "disconnected client_not_found", client)
      x
    end)
  end

  # mutations
  defp new_client(state, client, opts) do
    new_client_data = %Gameserver.Client{
      client: client,
      id: :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32)
    }

    Keyword.put(opts, :name, opts[:name] || new_client_data)

    new_client_data = Gameserver.Client.change_name(new_client_data, opts[:name])

    color = %{
      "daniel" => {0, 0.5, 1.0, 1.0}
    }

    new_client_data = %{new_client_data | color: Map.get(color, opts[:name], {1, 1, 1, 1})}

    # alert existing clients of new client
    Gameserver.Socket.broadcast(
      "new_client #{new_client_data.id} #{new_client_data.name}",
      state.socket,
      self(),
      state.clients
    )

    state = Map.put(state, :clients, Map.put(state.clients, client, new_client_data))

    Logger.debug("Client Connected: #{inspect(client)}\nClients: #{inspect(state.clients)}")

    state.clients |> IO.inspect()

    :ok =
      Socket.Datagram.send(
        state.socket,
        "l2d_test_game v#{state.server_version} accepted #{new_client_data.id}",
        client
      )

    # send all current data to new client
    state.clients
    # |> Enum.filter(fn {k, _} -> k != client end)
    |> Enum.each(fn {_, data} ->
      payload = "new_client #{data.id} #{data.name}"
      Socket.Datagram.send(state.socket, payload, client)
      Logger.debug(payload)
    end)

    # send bullets
    state.bullets
    |> Enum.each(fn {id, bullet} ->
      Gameserver.Socket.broadcast(
        "new_bullet #{Gameserver.Bullet.init_packet(id, bullet)}",
        state.socket,
        self(),
        state.clients
      )
    end)

    # send barrels
    state.barrels
    |> Enum.each(fn {id, barrel} ->
      Gameserver.Socket.broadcast(
        "new_barrel #{Gameserver.Barrel.init_packet(id, barrel)}",
        state.socket,
        self(),
        state.clients
      )
    end)

    {:ok, new_client_data, state}
  end

  defp update_client(state, client, data) do
    case state.clients[client] do
      nil ->
        {:error, :error, state}

      client_data ->
        merged_data = Map.merge(client_data, data)
        {:ok, merged_data, %{state | clients: %{state.clients | client => merged_data}}}
    end
  end

  defp remove_client(state, client) do
    # TODO: handle errors
    {old_client, clients} = Map.pop(state.clients, client)
    state = %{state | clients: clients}

    Logger.debug("Client Disconnected: #{inspect(client)}\nClients: #{inspect(state.clients)}")

    Gameserver.Socket.broadcast(
      "remove_client #{old_client.id}",
      state.socket,
      self(),
      state.clients
    )

    {:ok, old_client, state}
  end

  defp new_bullet(state, bullet) do
    id = state.next_bullet_id
    state = Map.put(state, :bullets, Map.put(state.bullets, id, bullet))

    # alert existing clients of new bullet
    Gameserver.Socket.broadcast(
      "new_bullet #{Gameserver.Bullet.init_packet(id, bullet)}",
      state.socket,
      self(),
      state.clients
    )

    {:ok, bullet, Map.put(state, :next_bullet_id, id + 1)}
  end

  defp update_bullet(state, id, bullet) do
    case state.bullets[id] do
      nil ->
        {:error, :error, state}

      bullet_data ->
        merged_bullet_data = Map.merge(bullet_data, bullet)

        {:ok, merged_bullet_data, %{state | bullets: %{state.bullets | id => merged_bullet_data}}}
    end
  end

  defp remove_bullet(state, id) do
    {removed_bullet, remaining_bullets} = Map.pop(state.bullets, id)

    # alert existing clients of removed bullet
    Gameserver.Socket.broadcast(
      "remove_bullet #{id}",
      state.socket,
      self(),
      state.clients
    )

    {:ok, removed_bullet, %{state | bullets: remaining_bullets}}
  end

  defp new_barrel(state, barrel) do
    id = state.next_barrel_id
    state = Map.put(state, :barrels, Map.put(state.barrels, id, barrel))

    # alert existing clients of new barrel
    Gameserver.Socket.broadcast(
      "new_barrel #{Gameserver.Barrel.init_packet(id, barrel)}",
      state.socket,
      self(),
      state.clients
    )

    {:ok, barrel, Map.put(state, :next_barrel_id, id + 1)}
  end

  defp update_barrel(state, id, barrel) do
    case state.barrels[id] do
      nil ->
        {:error, :error, state}

      barrel_data ->
        merged_barrel_data = Map.merge(barrel_data, barrel)

        {:ok, merged_barrel_data, %{state | barrels: %{state.barrels | id => merged_barrel_data}}}
    end
  end

  defp remove_barrel(state, id) do
    {removed_barrel, remaining_barrels} = Map.pop(state.barrels, id)

    # alert existing clients of removed barrel
    Gameserver.Socket.broadcast(
      "remove_barrel #{id}",
      state.socket,
      self(),
      state.clients
    )

    {:ok, removed_barrel, %{state | barrels: remaining_barrels}}
  end

  defp fire_client_active_secondary_weapon(state, client_key) do
    client = state.clients[client_key]
    weapon = Gameserver.Weapon.fired(Gameserver.Client.active_secondary_weapon(client))

    {:ok, _, state} =
      update_client(
        state,
        client_key,
        Gameserver.Client.update_weapon(client, client.active_secondary_weapon, weapon)
      )

    {mx, my} = Graphmath.Vec2.subtract(client.aimpos, client.pos)
    bullet = Gameserver.Weapon.generate_bullet(weapon, client.pos, {mx, my}, client.id)
    new_bullet(state, bullet)
  end

  defp fire_client_active_weapon(state, client_key) do
    client = state.clients[client_key]
    weapon = Gameserver.Weapon.fired(Gameserver.Client.active_weapon(client))

    {:ok, _, state} =
      update_client(
        state,
        client_key,
        Gameserver.Client.update_weapon(client, client.active_weapon, weapon)
      )

    {mx, my} = Graphmath.Vec2.subtract(client.aimpos, client.pos)
    bullet = Gameserver.Weapon.generate_bullet(weapon, client.pos, {mx, my}, client.id)
    new_bullet(state, bullet)
  end

  # internal update tick stuff
  def handle_info(:update, state), do: {:noreply, game_tick(state)}

  defp schedule_update(), do: Process.send_after(self(), :update, @update_time_ms)

  defp get_dt(state) do
    now = DateTime.utc_now()
    {DateTime.diff(now, state.last_tick, :microseconds) / 1_000_000, now}
  end

  defp game_tick(state) do
    schedule_update()

    {dt, new_last_tick} = get_dt(state)

    clients = state.clients
    bullets = state.bullets

    num_clients = length(Map.keys(clients))
    num_bullets = length(Map.keys(bullets))

    state = tick_state(state, dt)

    bullets_data =
      bullets
      |> Enum.map(fn {id, bullet} -> Gameserver.Bullet.update_packet(id, bullet) end)
      |> Enum.join("\n")

    clients_data =
      clients
      |> Enum.map(fn {client, data} -> Gameserver.Client.update_packet(data) end)
      |> Enum.join("\n")

    payload = "up\n#{num_clients}\n#{clients_data}\n#{num_bullets}\n#{bullets_data}"

    # TODO: possibly packet IDs to prevent out-of-order errors?

    # send packet to all clients
    clients
    |> Enum.each(fn {client, _} -> Socket.Datagram.send(state.socket, payload, client) end)

    Map.put(state, :last_tick, new_last_tick)
  end

  defp tick_state(state, dt), do: state |> tick_clients(dt) |> tick_bullets(dt)

  defp tick_bullets(state, dt) do
    # TODO: clear dead bullets
    # TODO: mark bullets for deletion
    case length(Map.keys(state.bullets)) do
      0 ->
        state

      _ ->
        state.bullets
        |> Enum.reduce(state, fn b, state -> tick_bullet(b, state, dt) end)
    end
  end

  defp tick_clients(state, dt) do
    case length(Map.keys(state.clients)) do
      0 -> state
      _ -> state.clients |> Enum.reduce(state, fn c, state -> tick_client(c, state, dt) end)
    end
  end

  defp tick_client({k, client}, state, dt) do
    {:ok, updated_client, state} = update_client(state, k, Gameserver.Client.update(client, dt))

    cond do
      updated_client.since_last_update >= 10 ->
        {:ok, _, state} = remove_client(state, k)
        state

      true ->
        state =
          Enum.reduce(state.barrels, state, fn {barrel_id, barrel}, state ->
            {w, h} = barrel.size
            # average of two dimensions and halved for radius
            r = (w + h) / 4
            # add client size to radius
            {w, h} = client.size
            r = r + (w + h) / 4

            case Gameserver.Barrel.check_collide_circle(
                   client.pos,
                   updated_client.pos,
                   barrel.pos,
                   r
                 ) do
              true ->
                p =
                  Graphmath.Vec2.add(
                    barrel.pos,
                    Graphmath.Vec2.scale(
                      Graphmath.Vec2.normalize(
                        Graphmath.Vec2.subtract(updated_client.pos, barrel.pos)
                      ),
                      r
                    )
                  )

                updated_client

                {:ok, _, state} =
                  update_client(
                    state,
                    k,
                    Gameserver.Client.set_pos(updated_client, p)
                  )

                state

              _ ->
                state
            end
          end)

        state =
          case Gameserver.Client.firing?(client) &&
                 Gameserver.Client.active_weapon(client) |> Gameserver.Weapon.can_fire?() do
            true ->
              {:ok, _, state} = fire_client_active_weapon(state, k)
              state

            false ->
              state
          end

        case Gameserver.Client.secondary_firing?(client) &&
               Gameserver.Client.active_secondary_weapon(client) |> Gameserver.Weapon.can_fire?() do
          true ->
            {:ok, _, state} = fire_client_active_secondary_weapon(state, k)
            state

          false ->
            state
        end
    end
  end

  defp tick_bullet({k, orig_bullet}, state, dt) do
    # TODO: cleanup
    # Logger.warn("#{inspect({{k, bullet}, state, dt})}")
    updated_bullet = Gameserver.Bullet.update(orig_bullet, dt)
    owner = get_client_by_id(state, updated_bullet.owner)

    {updated_bullet, state} =
      Enum.reduce(
        state.clients |> Enum.filter(fn {key, client} -> client.respawn_time <= 0 end),
        {updated_bullet, state},
        fn {client_key, client}, {updated_bullet, state} ->
          {x, y} = client.size
          # average of two dimensions and halved for radius
          r = (x + y) / 4

          case Gameserver.Bullet.check_collide_circle(
                 orig_bullet,
                 updated_bullet.pos,
                 client.pos,
                 r
               ) do
            true ->
              old_health = client.health

              {_, new_client, new_state} =
                update_client(
                  state,
                  client_key,
                  Gameserver.Client.damage(client, orig_bullet.damage)
                )

              # TODO: track deaths

              new_health = new_client.health

              new_state =
                cond do
                  old_health > 0 && new_health <= 0 && owner != nil ->
                    Gameserver.Socket.screen_message(
                      owner.name <> " killed " <> new_client.name <> ". (#{owner.score + 1})",
                      new_state.socket,
                      new_state.clients
                    )

                    {:ok, _, new_state} =
                      update_client(
                        new_state,
                        owner.client,
                        Gameserver.Client.inc_score(owner)
                      )

                    new_state

                  true ->
                    new_state
                end

              {Gameserver.Bullet.die(updated_bullet), new_state}

            _ ->
              {updated_bullet, state}
          end
        end
      )

    {updated_bullet, state} =
      case Gameserver.Bullet.dead?(updated_bullet) do
        false ->
          Enum.reduce(state.barrels, {updated_bullet, state}, fn {barrel_id, barrel},
                                                                 {updated_bullet, state} ->
            {w, h} = barrel.size
            # average of two dimensions and halved for radius
            r = (w + h) / 4

            case Gameserver.Bullet.check_collide_circle(
                   orig_bullet,
                   updated_bullet.pos,
                   barrel.pos,
                   r
                 ) do
              true ->
                {_, _, new_state} =
                  update_barrel(
                    state,
                    barrel_id,
                    Gameserver.Barrel.damage(barrel, updated_bullet.damage)
                  )

                {Gameserver.Bullet.die(updated_bullet), new_state}

              _ ->
                {updated_bullet, state}
            end
          end)

        _ ->
          {updated_bullet, state}
      end

    case Gameserver.Bullet.dead?(updated_bullet) do
      true ->
        {_, _, state} = remove_bullet(state, k)
        state

      _ ->
        {_, _, state} = update_bullet(state, k, updated_bullet)
        state
    end
  end

  defp get_client_by_id(state, id) do
    case Enum.filter(state.clients, fn {_, c} -> c.id == id end) do
      [{_, client}] -> client
      _ -> nil
    end
  end
end
