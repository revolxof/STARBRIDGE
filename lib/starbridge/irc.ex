defmodule Starbridge.IRC do
  import Starbridge.Env
  alias Starbridge.Server
  require Starbridge.Logger, as: Logger
  use GenServer

  def start_link(client) do
    GenServer.start_link(__MODULE__, client, name: __MODULE__)
  end

  @impl true
  def init(client) do
    ExIRC.Client.add_handler client, self()
    ExIRC.Client.connect! client, env(:irc_address), env(:irc_port, :int)

    Server.register(:irc, __MODULE__)
    {:ok, client}
  end

  @impl true
  def handle_info({:connected, _, _}, client) do
    Logger.debug("Connected to IRC server")
    ExIRC.Client.logon client, env(:irc_password), env(:irc_nickname), env(:irc_username), env(:irc_realname)

    {:noreply, client}
  end

  def handle_info({:received, content, sender_info}, client) do
    Logger.debug("<#{sender_info.nick}> #{content}")
    {:noreply, client}
  end

  def handle_info({:received, msg, info, channel}, client) do
    Logger.debug("<#{info.nick}#{channel} @ #{env(:irc_address)}> #{msg}")
    Server.send_message(:irc, env(:irc_address), {channel, channel}, msg, info.nick)
    {:noreply, client}
  end

  def handle_info(:logged_in, client) do
    Logger.debug("Logged in")

    channels = Starbridge.Util.IRC.parse_channels env(:irc_channels)
    Enum.map(channels, fn {channel, pass} -> join_channel(client, channel, pass) end)

    {:noreply, client}
  end

  def handle_info({:joined, channel}, client) do
    Logger.debug("Joined channel #{channel}")
    {:noreply, client}
  end

  def handle_info({:unrecognized, name, msg}, client) do
    Logger.info("#{name}: #{msg.args |> Enum.join(" ")}")
    {:noreply, client}
  end

  def handle_info({:notice, msg, _}, client) do
    Logger.notice("#{msg}")
    {:noreply, client}
  end

  def handle_info(_, client) do
    {:noreply, client}
  end

  @impl true
  def handle_cast({:send_message, {target_channel, content}}, client) do
    send_message(client, target_channel, content)
    {:noreply, client}
  end

  def join_channel(client, name, nil) do
    ExIRC.Client.join(client, name)
  end

  def join_channel(client, name, pass) do
    ExIRC.Client.join(client, name, pass)
  end

  def send_message(client, channel, content) do
    ExIRC.Client.msg(client, :privmsg, channel, content)
  end
end
