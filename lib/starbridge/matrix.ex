defmodule Starbridge.Matrix do
  alias Starbridge.Server
  import Starbridge.Env
  require Starbridge.Logger, as: Logger

  use GenServer

  defmodule State do
    defstruct address: nil, client: nil, rooms: [], sync_completed: false
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
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

    {:ok,
     %State{
       address: env(:matrix_address),
       client: client,
       rooms: join_rooms(client),
       sync_completed: false
     }}
  end

  defp join_rooms(client) do
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
  end

  @impl true
  def handle_info({:polyjuice_client, :initial_sync_completed}, state) do
    {:noreply, %{state | sync_completed: true}}
  end

  @impl true
  def handle_info({:polyjuice_client, :message, {channel_id, msg}}, state)
      when state.sync_completed do
    if Enum.member?(state.rooms, channel_id) do
      content = msg["content"]["body"]
      sender = msg["sender"]
      Logger.debug("Received message from #{sender} in #{channel_id}: #{content}")
      Server.send_message(:matrix, state.addr, {channel_id, channel_id}, content, sender)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_message, {target_channel, content}}, state) do
    Polyjuice.Client.Room.send_message(state.client, target_channel, content)
    {:noreply, state}
  end
end
