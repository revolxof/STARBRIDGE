defmodule Starbridge.Adapters.Matrix do
  alias Starbridge.Structure
  alias Starbridge.Structure.Message
  import Starbridge.Env
  require Starbridge.Logger, as: Logger

  use GenServer

  def enabled() do
    env(:matrix_enabled)
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
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

    GenServer.cast(
      Starbridge.Server,
      {:register_client, %Structure.Client{platform: :matrix, server: __MODULE__}}
    )

    join_rooms(client)

    # Server.register(:matrix, __MODULE__)

    {:ok,
     %{
       client: client,
       sync_completed: false
     }}
  end

  defp join_rooms(client) do
    env(:recasts)
    |> Starbridge.Util.get_channels(:matrix)
    |> Enum.map(fn channel ->
      ret = Polyjuice.Client.Room.join(client, channel.id, [env(:matrix_address)])

      case ret do
        {:ok, room_id} ->
          Logger.debug("Joined #{room_id}.")

          GenServer.cast(
            Starbridge.Server,
            {:register_channel, channel |> Structure.Channel.with_name(room_id)}
          )

          room_id

        _ ->
          Logger.error("Failed to join #{channel.id}: #{inspect(ret)}")
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
    content = msg["content"]["body"]
    sender = msg["sender"]
    Logger.debug("Received message from #{sender} in #{channel_id}: #{content}")

    r_channel = Starbridge.Util.get_channel(env(:recasts), channel_id, :matrix)

    if !is_nil(r_channel) do
      message =
        Message.with_content(content)
        |> Message.with_nickname(sender)
        |> Message.with_server(env(:matrix_address))
        |> Message.with_channel(r_channel, true)

      GenServer.cast(Starbridge.Server, {:recast_message, message})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_message, {channel, content}}, state) do
    Polyjuice.Client.Room.send_message(state.client, channel.id, content)
    {:noreply, state}
  end
end
