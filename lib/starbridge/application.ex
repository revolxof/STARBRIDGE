defmodule Starbridge.Application do
  use Application
  import Starbridge.Env

  @impl true
  def start(_ty, args) do
    {parsed, _, _} = OptionParser.parse(args, strict: ["tcp-debug": :boolean])

    if parsed[:"tcp-debug"] do
      :dbg.start()
      :dbg.tracer()
      :dbg.tp(:gen_tcp, :send, 2, [])
      :dbg.p(:all, :c)
    end

    client_modules = [
      {env(:discord_enabled, :boolean), Starbridge.Discord},
      {env(:irc_enabled, :boolean), Starbridge.IRC},
      {env(:matrix_enabled, :boolean), Starbridge.Matrix}
    ]

    children =
      Enum.filter(client_modules, fn {enabled, _child} -> enabled end)
      |> Enum.map(fn {_enabled, child} -> child end)

    opts = [strategy: :one_for_one, name: Starbridge.Supervisor]

    Supervisor.start_link([Starbridge.Server | children], opts)
  end
end
