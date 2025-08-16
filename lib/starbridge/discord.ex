defmodule Starbridge.Discord do
  @behaviour Nostrum.Consumer

  alias Starbridge.Server
  import Starbridge.Env
  require Starbridge.Logger, as: Logger

  use GenServer

  def start_link(client) do
    GenServer.start_link(__MODULE__, client, name: __MODULE__)
  end

  @impl true
  def init(client) do
    Nostrum.ConsumerGroup.join()
    {:ok, client}
  end

  @impl true
  def handle_cast({:send_message, {target_channel, content}}, client) do
    Nostrum.Api.Message.create(target_channel |> String.to_integer(), content)

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

    Server.register(:discord, Starbridge.Discord)

    discord_status = env(:discord_status)

    if !is_nil(discord_status) do
      status_type = Starbridge.Util.status_type(env(:discord_status_type))

      Nostrum.Api.Self.update_status(:online, discord_status, status_type)
      Logger.debug("Using discord status \"#{discord_status}\"")
    end
  end

  def handle_event({:MESSAGE_CREATE, msg, _}) when not msg.author.bot do
    channels =
      env(:discord_channels)
      |> String.split(",")
      |> Enum.map(fn s -> String.trim(s) |> String.to_integer() end)

    if channels |> Enum.member?(msg.channel_id) do
      {:ok, channel} = Nostrum.Api.Channel.get(msg.channel_id)
      {:ok, guild} = Nostrum.Api.Guild.get(msg.guild_id)

      Logger.debug(
        "<#{msg.author.username}##{msg.author.discriminator} in ##{channel.name} @ #{guild.name}> #{msg.content}"
      )

      Server.send_message(
        :discord,
        guild.name,
        {"#" <> channel.name, channel.id |> Integer.to_string()},
        msg.content,
        msg.author.username
      )
    end
  end

  def handle_event(_) do
    :noop
  end
end
