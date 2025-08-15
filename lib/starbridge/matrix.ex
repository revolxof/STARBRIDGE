defmodule Starbridge.Matrix do
  alias Starbridge.Server
  import Starbridge.Env
  require Starbridge.Logger, as: Logger

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, pid} =
      Polyjuice.Client.start_link(
        env(:matrix_address),
        access_token: env(:matrix_token),
        user_id: env(:matrix_user),
        storage: Polyjuice.Client.Storage.Ets.open(),
        handler: self()
      )

    client = Polyjuice.Client.get_client(pid)
    Server.register(:matrix, __MODULE__)

    rooms =
      env(:matrix_rooms)
      |> String.split(",")
      |> Enum.map(fn r ->
        ret = Polyjuice.Client.Room.join(client, r, [env(:matrix_address)])

        case ret do
          {:ok, room_id} ->
            Logger.debug("Joined #{room_id}.")
            room_id

          _ ->
            Logger.error("Failed to join #{r}: #{inspect(ret)}")
        end
      end)

    {:ok, {env(:matrix_address), client, rooms, false}}
  end

  @impl true
  def handle_info(message, state) do
    {addr, client, rooms, synced} = state

    sync_completed =
      case message do
        {:polyjuice_client, :message, {channel_id, msg}} ->
          with true <- synced, true <- Enum.member?(rooms, channel_id) do
            content = msg["content"]["body"]
            sender = msg["sender"]
            Logger.debug("Received message from #{sender} in #{channel_id}: #{content}")
            Server.send_message(:matrix, addr, {channel_id, channel_id}, content, sender)

            synced
          else
            _ -> synced
          end

        {:polyjuice_client, :initial_sync_completed} ->
          true

        _ ->
          synced
      end
    {:noreply, {addr, client, rooms, sync_completed}}
  end

  @impl true
  def handle_cast({:send_message, {target_channel, content}}, state) do
    {_, client, _, _} = state
    Polyjuice.Client.Room.send_message(client, target_channel, content)
    {:noreply, state}
  end
end
