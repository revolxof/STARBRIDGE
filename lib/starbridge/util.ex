defmodule Starbridge.Util do

  def format_content(display_string, author, channel, server, content) do
    display_string
    |> String.replace("$author", author)
    |> String.replace("$channel", channel)
    |> String.replace("$content", content)
    |> String.replace("$server", server)
  end

  def status_type(type) do
    case type do
      "playing" -> 0
      "streaming" -> 1
      "listening" -> 2
      "watching" -> 3
      _ -> :error
    end
  end

  def parse_recast(input) do
    input
    |> String.trim()
    |> String.split(~r/(\n|\r\n)/)
    |> Enum.flat_map(fn i ->
      {lhs, arrow, rhs} = parse_one_recast(i)
      case arrow do
        :unidirectional -> [{lhs, rhs}]
        :bidirectional -> [{lhs, rhs}, {rhs, lhs}]
      end
    end)
    |> Enum.dedup()
    |> Enum.group_by(
      fn {{platform, _}, _} -> platform end,
      fn {{_, src_channel}, rhs} -> {src_channel, rhs} end
      )
    |> Enum.map(
      fn {platform, channels} ->
        Enum.group_by(
          channels,
          fn {channel, _} -> {platform, channel} end,
          fn {_, target} -> target end
        )
      end)
    |> Enum.reduce(fn e, acc -> Map.merge(e, acc) end)
  end

  defp parse_one_recast(input) do
    [lhs, arrow, rhs] = input
    |> String.split(~r/\s+/)

    arrow = parse_arrow(arrow)
    [lhs, rhs] = parse_platform_channel_pair([lhs, rhs])

    {lhs, arrow, rhs}
  end

  defp parse_arrow("<->"), do: :bidirectional
  defp parse_arrow("->"), do: :unidirectional

  defp parse_platform_channel_pair(input) when is_binary(input) do
    [plat, chan] = input
    |> String.split(":", parts: 2)

    if plat == "irc" do
      Starbridge.Util.IRC.parse_channel(chan)
    else
      chan
    end

    {plat |> String.to_atom, chan}
  end

  defp parse_platform_channel_pair(input) when is_list(input) do
    Enum.map(input, &parse_platform_channel_pair/1)
  end

  defmodule IRC do
    def parse_channels(input) do
      input
      |> String.split(",")
      |> Enum.map(fn i -> String.trim(i) |> parse_channel end)
    end

    def parse_channel("#" <> name), do: {"#" <> name, nil}
    def parse_channel("(" <> data) do
      {channel, pass} = String.replace(data, ~r/[()]/, "")
      |> String.split(~r/\s+/)
      |> List.to_tuple

      {channel, pass}
    end
  end
end
