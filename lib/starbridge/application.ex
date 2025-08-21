defmodule Starbridge.Application do
  use Application

  @impl true
  def start(_ty, args) do
    {parsed, _, _} = OptionParser.parse(args, strict: ["tcp-debug": :boolean])

    if parsed[:"tcp-debug"] do
      :dbg.start()
      :dbg.tracer()
      :dbg.tp(:gen_tcp, :send, 2, [])
      :dbg.p(:all, :c)
    end

    client_modules =
      :code.all_available()
      |> Enum.map(fn x -> elem(x, 0) |> to_string end)
      |> Enum.filter(&String.starts_with?(&1, "Elixir.Starbridge.Adapters"))
      |> Enum.flat_map(fn mod ->
        m = String.to_atom(mod)
        if apply(m, :enabled, []) do
          [m]
        else
          []
        end
      end)

    opts = [strategy: :one_for_one, name: Starbridge.Supervisor]

    Supervisor.start_link([Starbridge.Server | client_modules], opts)
  end
end
