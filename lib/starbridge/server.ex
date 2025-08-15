defmodule Starbridge.Server do
  use GenServer
  require Starbridge.Logger, as: Logger
  import Starbridge.Util
  alias Starbridge.Env

  def register(name, server) do
    Logger.debug("#{name} client registered")

    GenServer.cast(__MODULE__, {:register_client, {name, server}})
  end

  def send_message(platform, serv_name, channel, content, nick) do
    GenServer.cast(__MODULE__, {:message, {platform, serv_name, channel, content, nick}})
  end

  def start_link(_) do
    recasts = File.read!(".recast")
    |> Starbridge.Util.parse_recast

    GenServer.start_link(__MODULE__, %{ recasts: recasts, clients: [] }, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:register_client, {name, server}}, state) do
    registered_client = Map.update(state, :clients, nil, fn clients -> [ {name, server} | clients ] end)
    {:noreply, registered_client}
  end

  @impl true
  def handle_cast({:message, {platform, serv_name, {channel_name, channel_id}, content, nick}}, state) do
    recasts = state.recasts
    |> Map.get({platform, channel_id})

    if !is_nil(recasts) do
      recast_messages(recasts, state.clients, serv_name, channel_name, content, nick)
    end

    {:noreply, state}
  end

  def recast_messages(targets, clients, serv_name, channel, content, nick) do
    all_registered = Enum.flat_map(clients, fn {registered_platform, _} ->
      Enum.filter(targets, fn {platform, _} ->
        registered_platform == platform
      end)
    end)

    serv_name_trunc = serv_name |> String.slice(0..20)
    serv_name =
      if serv_name_trunc |> String.length() == serv_name |> String.length() do
        serv_name
      else
        serv_name_trunc <> "..."
      end

    Enum.map(all_registered, fn {platform, target_channel} ->
      {_, server} = Enum.find(clients, fn {p, _} -> p == platform end)
      content = format_content(Env.env(:display), nick, channel, serv_name, content)
      GenServer.cast(server, {:send_message, {target_channel, content}})
    end)
  end
end
