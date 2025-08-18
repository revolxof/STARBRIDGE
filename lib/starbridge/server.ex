defmodule Starbridge.Server do
  use GenServer
  require Starbridge.Logger, as: Logger

  import Starbridge.{Util, Env}
  alias Starbridge.Structure

  defmodule State do
    defstruct clients: %{}

    @type t :: %__MODULE__{
            clients: map()
          }
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:register_client, client}, state) do
    Logger.debug("Client registered: #{client.platform}")
    {:noreply, %{state | clients: Map.put(state.clients, client.platform, client.server)}}
  end

  @impl true
  def handle_cast({:register_channel, nil}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:register_channel, channel}, state) do
    Logger.debug("Channel registered: #{channel.platform} @ #{channel.name} (#{channel.id})")
    Application.put_env(:starbridge, :recasts, Starbridge.Util.register(env(:recasts), channel))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:recast_message, %Structure.Message{} = message}, state) do
    recast =
      env(:recasts)
      |> Starbridge.Util.registered()
      |> Starbridge.Util.get_from(message.platform, message.channel.id)

    recast_messages(recast, state, message)

    {:noreply, state}
  end

  def recast_messages(nil, _, _) do
    :noop
  end

  def recast_messages({_from, to}, state, %Structure.Message{} = message) do
    serv_name_trunc = message.server_name |> String.slice(0..20)

    serv_name =
      if serv_name_trunc |> String.length() == message.server_name |> String.length() do
        message.server_name
      else
        serv_name_trunc <> "..."
      end

    Enum.map(to, fn channel ->
      server = state.clients[channel.platform]

      content =
        format_content(
          env(:display),
          message.nickname,
          message.channel.name,
          serv_name,
          message.content
        )

      GenServer.cast(server, {:send_message, {channel, content}})
    end)
  end
end
