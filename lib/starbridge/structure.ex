defmodule Starbridge.Structure do
  defmodule Channel do
    defstruct [:name, :id, :password, :platform, registered: false]

    @type t :: %__MODULE__{
            name: String.t(),
            id: String.t(),
            password: String.t(),
            platform: atom(),
            registered: boolean()
          }

    def with_password(%Channel{} = channel \\ %Channel{}, password) do
      %{channel | password: password}
    end

    def with_id(%Channel{} = channel \\ %Channel{}, id) do
      %{channel | id: id}
    end

    def with_name(%Channel{} = channel \\ %Channel{}, name) do
      %{channel | name: name}
    end

    def with_platform(channel \\ %Channel{}, platform)

    def with_platform(%Channel{} = channel, platform) when is_binary(platform) do
      %{channel | platform: platform |> String.to_atom()}
    end

    def with_platform(%Channel{} = channel, platform) when is_atom(platform) do
      %{channel | platform: platform}
    end

    def register(%Channel{} = channel) do
      %{channel | registered: true}
    end

    def display_name(%Channel{} = channel) do
      if !is_nil(channel.name) do
        channel.name
      else
        channel.id
      end
    end

    def merge(%Channel{} = channel, %Channel{} = other \\ %Channel{}) do
      if channel.id !== other.id || channel.platform !== other.platform do
        throw "Tried to merge on incompatible channels."
      end
      Map.merge(channel, other, fn _, v1, v2 ->
        case [v1, v2] do
          [nil, nil] -> nil
          [v1, nil] -> v1
          [nil, v2] -> v2
          [_, v2] -> v2
        end
      end)
    end
  end

  defmodule Client do
    defstruct [:platform, :server]

    @type t :: %__MODULE__{
            platform: atom(),
            server: GenServer.server()
          }

    def with_platform(%Client{} = client, platform) do
      %{client | platform: platform}
    end

    def with_server(%Client{} = client, server) do
      %{client | server: server}
    end
  end

  defmodule Message do
    # {platform, serv_name, {channel_name, channel_id}, content, nick}
    defstruct [:platform, :server_name, :content, :nickname, channel: %Channel{}]

    @type t :: %__MODULE__{
            platform: atom(),
            server_name: String.t(),
            content: String.t(),
            nickname: String.t(),
            channel: Channel.t()
          }

    def with_content(%Message{} = message \\ %Message{}, content) do
      %{message | content: content}
    end

    def with_nickname(%Message{} = message \\ %Message{}, name) do
      %{message | nickname: name}
    end

    def with_channel(%Message{} = message \\ %Message{}, %Channel{} = channel) do
      %{message | channel: channel}
    end

    def with_channel(%Message{} = message, %Channel{} = channel, inherit) do
      if inherit do
        %{message | channel: channel}
        |> Message.with_platform(channel.platform)
      else
        with_channel(message, channel)
      end
    end

    def with_server(%Message{} = message \\ %Message{}, server) do
      %{message | server_name: server}
    end

    def with_platform(%Message{} = message \\ %Message{}, platform) do
      %{message | platform: platform}
    end

    def with_platform(%Message{} = message, platform, propagate) do
      if propagate do
        %{message | platform: platform, channel: Channel.with_platform(message.channel, platform)}
      else
        Message.with_platform(message, platform)
      end
    end
  end
end
