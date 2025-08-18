defmodule Starbridge.Util do
  alias Starbridge.Structure

  def format_content(display_string, author, channel, server, content) do
    display_string
    |> String.replace("$author", author)
    |> String.replace("$channel", channel)
    |> String.replace("$content", content)
    |> String.replace("$server", server)
  end

  def status_type(:playing), do: 0
  def status_type(:streaming), do: 1
  def status_type(:listening), do: 2
  def status_type(:watching), do: 3

  def get_channels(recasts, platform) do
    get_channels(recasts)
    |> Enum.filter(fn c -> c.platform === platform end)
  end

  def get_channels(recasts) do
    recasts
    |> Enum.reduce([], fn {lhs, rhs}, acc -> [[lhs | rhs] | acc] end)
    |> Enum.flat_map(&Function.identity/1)
    |> Enum.uniq()
  end

  def get_channel(recasts, id) when is_binary(id) do
    get_channels(recasts)
    |> Enum.find(fn c -> c.id === id end)
  end

  def get_channel(recasts, id) when is_integer(id) do
    get_channels(recasts)
    |> Enum.find(fn c -> c.id === id |> Integer.to_string() end)
  end

  def get_channel(recasts, id, platform) when is_binary(id) do
    get_channels(recasts, platform)
    |> Enum.find(fn c -> c.id === id end)
  end

  def get_channel(recasts, id, platform) when is_integer(id) do
    get_channels(recasts, platform)
    |> Enum.find(fn c -> c.id === id |> Integer.to_string() end)
  end

  def get_from(recasts, platform) do
    recasts
    |> Map.filter(fn {from, _} -> from.platform === platform end)
  end

  def get_from(recasts, platform, id) when is_binary(id) do
    recasts
    |> Map.filter(fn {from, _} -> from.platform === platform && from.id === id end)
    |> Map.to_list()
    |> List.first()
  end

  def get_to(recasts, platform) do
    recasts
    |> Enum.map(fn {from, to} ->
      {from, Enum.filter(to, fn ch -> ch.platform === platform end)}
    end)
    |> Enum.filter(fn {_, ch} -> !Enum.empty?(ch) end)
    |> Map.new()
  end

  def register(recasts, %Structure.Channel{} = channel) do
    recasts
    |> Enum.map(fn {from, to} ->
      {if from.id === channel.id && from.platform === channel.platform do
         channel
         |> Structure.Channel.register()
       else
         from
       end,
       Enum.map(to, fn to_ch ->
         if to_ch.id === channel.id && to_ch.platform === channel.platform do
           channel
           |> Structure.Channel.register()
         else
           to_ch
         end
       end)}
    end)
    |> Map.new()
  end

  def registered(recasts) do
    recasts
    |> Map.filter(fn {from, _} -> from.registered end)
    |> Enum.map(fn {from, to} ->
      {from, Enum.filter(to, fn ch -> ch.registered end)}
    end)
    |> Enum.filter(fn {_, ch} -> !Enum.empty?(ch) end)
    |> Map.new()
  end
end
