defmodule Starbridge.IRC do
  import Starbridge.Env

  alias Starbridge.Structure.Message
  alias Starbridge.Structure
  require Starbridge.Logger, as: Logger
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, client} = ExIRC.start_link!()

    ExIRC.Client.add_handler(client, self())
    ExIRC.Client.connect!(client, env(:irc_address), env(:irc_port, :int))

    GenServer.cast(
      Starbridge.Server,
      {:register_client, %Structure.Client{platform: :irc, server: __MODULE__}}
    )

    # Server.register(:irc, __MODULE__)

    {:ok, client}
  end

  @impl true
  def handle_info({:connected, _, _}, client) do
    Logger.debug("Connected to IRC server")

    ExIRC.Client.logon(
      client,
      env(:irc_password),
      env(:irc_nickname),
      env(:irc_username),
      env(:irc_realname)
    )

    {:noreply, client}
  end

  def handle_info({:received, content, sender_info}, client) do
    Logger.debug("<#{sender_info.nick}> #{content}")
    {:noreply, client}
  end

  def handle_info({:received, msg, info, channel}, client) do
    Logger.debug("<#{info.nick}#{channel} @ #{env(:irc_address)}> #{msg}")

    r_channel = Starbridge.Util.get_channel(env(:recasts), channel, :irc)

    if !is_nil(r_channel) do
      message =
        Message.with_content(msg)
        |> Message.with_nickname(info.nick)
        |> Message.with_server(info.host)
        |> Message.with_channel(r_channel, true)

      GenServer.cast(Starbridge.Server, {:recast_message, message})
    end

    # Server.send_message(:irc, env(:irc_address), {channel, channel}, msg, info.nick)
    {:noreply, client}
  end

  def handle_info(:logged_in, client) do
    Logger.debug("Logged in")

    env(:recasts)
    |> Starbridge.Util.get_channels(:irc)
    |> Enum.map(fn ch -> join_channel(client, ch) end)

    {:noreply, client}
  end

  def handle_info({:joined, channel}, client) do
    Logger.debug("Joined channel #{channel}")

    GenServer.cast(
      Starbridge.Server,
      {:register_channel, Starbridge.Util.get_channel(env(:recasts), channel, :irc)}
    )

    {:noreply, client}
  end

  def handle_info({:unrecognized, name, msg}, client) do
    Logger.info("#{name}: #{msg.args |> Enum.join(" ") |> String.trim("\r\n")}")
    {:noreply, client}
  end

  def handle_info({:notice, msg, _}, client) do
    Logger.notice("#{msg}")
    {:noreply, client}
  end

  def handle_info({:invited, _, channel_id}, client) do
    ch = env(:recasts)
    |> Starbridge.Util.get_channel(channel_id, :irc)

    join_channel(client, ch)

    {:noreply, client}
  end

  def handle_info(_, client) do
    {:noreply, client}
  end

  @impl true
  def handle_cast({:send_message, {channel, content}}, client) do
    send_message(client, channel.id, content)
    {:noreply, client}
  end

  def join_channel(client, %Structure.Channel{id: name, password: nil}) do
    ExIRC.Client.join(client, name)
  end

  def join_channel(client, %Structure.Channel{id: name, password: pass}) do
    ExIRC.Client.join(client, name, pass)
  end

  def join_channel(_, nil) do
    :noop
  end

  def send_message(client, channel, content) do
    ExIRC.Client.msg(client, :privmsg, channel, content)
  end
end
