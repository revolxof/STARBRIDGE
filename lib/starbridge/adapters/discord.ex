defmodule Starbridge.Adapters.Discord do

  @behaviour Nostrum.Consumer

  alias Starbridge.Structure.Channel
  alias Starbridge.Structure.Message
  alias Starbridge.Structure
  alias Starbridge.Util

  import Starbridge.Env
  require Starbridge.Logger, as: Logger

  use Starbridge.Adapter

  @impl true
  def enabled() do
    env(:discord_enabled)
  end

  @impl true
  def state() do
    %{
      consumer: __MODULE__,
      wrapped_token: fn -> env(:discord_token) end,
      intents: [
        :guild_messages,
        :message_content
      ]
    }
  end

  @impl true
  def child() do
    Nostrum.Bot
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  use GenServer

  @impl true
  def init(client) do
    {:ok, client}
  end

  @impl true
  def handle_cast({:send_message, {channel, content}}, client) do
    Nostrum.Api.Message.create(channel.id |> String.to_integer(), content)

    {:noreply, client}
  end

  @impl true
  def handle_info({:event, event}, state) do
    Task.start(fn ->
      try do
        __MODULE__.handle_event(event)
      rescue
        e ->
          Logger.error("Error in event handler: #{Exception.format(:error, e, __STACKTRACE__)}")
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_event({:READY, client, _}) do
    Logger.debug(
      "Logged in as #{client.user.username}##{client.user.discriminator} (#{client.user.id})"
    )

    GenServer.cast(
      Starbridge.Server,
      {:register_client, %Structure.Client{platform: :discord, server: __MODULE__}}
    )

    env(:recasts)
    |> Util.get_channels(:discord)
    |> Enum.map(fn channel ->
      with {:ok, ch} <- Nostrum.Api.Channel.get(channel.id |> String.to_integer()) do
        GenServer.cast(
          Starbridge.Server,
          {:register_channel,
           channel
           |> Channel.with_name(ch.name)}
        )
      end
    end)

    discord_status = env(:discord_status)

    if !is_nil(discord_status) do
      Nostrum.Api.Self.update_status(:online, {env(:discord_status_type), env(:discord_status)})
      Logger.debug("Using discord status \"#{discord_status}\"")
    end
  end

  def handle_event({:MESSAGE_CREATE, msg, _}) when is_nil(msg.author.bot) or not msg.author.bot do
    r_channel = Util.get_channel(env(:recasts), msg.channel_id, :discord)

    if !is_nil(r_channel) do
      {:ok, channel} = Nostrum.Api.Channel.get(msg.channel_id)
      {:ok, guild} = Nostrum.Api.Guild.get(msg.guild_id)

      Logger.debug(
        "<#{msg.author.username}##{msg.author.discriminator} in ##{channel.name} @ #{guild.name}> #{msg.content}"
      )

      message =
        Message.with_content(msg.content)
        |> Message.with_nickname(msg.author.username)
        |> Message.with_server(guild.name)
        |> Message.with_channel(r_channel, true)

      GenServer.cast(Starbridge.Server, {:recast_message, message})
    end
  end

  def handle_event(_), do: :ok
end
