defmodule Starbridge.Recast do
  alias Starbridge.Structure.Channel

  @cfg_splitter ~r/(?<!\\):/

  def parse("") do
    %{}
  end

  def parse(input) do
    input
    |> String.trim()
    |> String.split(~r/(\n|\r\n)/)
    |> Enum.flat_map(fn i ->
      {lhs, arrow, rhs} =
        parse_one_recast(i)

      interned =
        get_or_intern(lhs.id, lhs)
        |> get_or_intern(rhs.id, rhs)

      l = interned |> Map.get(lhs.id)
      r = interned |> Map.get(rhs.id)

      case arrow do
        :unidirectional -> [{l, r}]
        :bidirectional -> [{l, r}, {r, l}]
      end
    end)
    |> Enum.uniq()
    |> Enum.group_by(
      fn {lhs, _} -> lhs end,
      fn {_, rhs} -> rhs end
    )
  end

  defp parse_one_recast(input) do
    [lhs, arrow, rhs] =
      input
      |> String.split(~r/\s+/)

    arrow = parse_arrow(arrow)
    [lhs, rhs] = parse_platform_channel_pair([lhs, rhs])

    {lhs, arrow, rhs}
  end

  defp parse_arrow("<->"), do: :bidirectional
  defp parse_arrow("->"), do: :unidirectional

  defp parse_platform_channel_pair(input) when is_binary(input) do
    [platform, channel] =
      input
      |> String.split(":", parts: 2)

    parse_channel(channel) |> Channel.with_platform(platform)
  end

  defp parse_platform_channel_pair(input) when is_list(input) do
    Enum.map(input, &parse_platform_channel_pair/1)
  end

  def parse_channel("[" <> channel) do
    if !String.ends_with?(channel, "]") do
      throw(
        "The channel part of a recast term must end with a ] if it starts with an open brace: [#{channel}]"
      )
    end

    case String.trim_trailing(channel, "]") |> String.split(@cfg_splitter, parts: 3) do
      [id, "", ""] ->
        Channel.with_id(id)

      [id, "", name] ->
        Channel.with_id(id) |> Channel.with_name(name)

      [id, pass, ""] ->
        Channel.with_id(id) |> Channel.with_password(pass)

      [id, pass, name] ->
        Channel.with_id(id) |> Channel.with_password(pass) |> Channel.with_name(name)
    end
  end

  def parse_channel(channel) when is_binary(channel) do
    Channel.with_id(channel)
  end

  def get_or_intern(map \\ %{}, id, %Channel{} = new) do
    if !Map.has_key?(map, id) do
      Map.put(map, id, new)
    else
      {_, out} =
        map
        |> Map.get_and_update!(id, fn old ->
          channel =
            if old.platform !== new.platform do
              old
            else
              Channel.merge(old, new)
            end

          {old, channel}
        end)

      out
    end
  end
end
