defmodule Starbridge.MixProject do
  use Mix.Project

  def project do
    [
      app: :starbridge,
      version: "0.1.0",
      elixir: "~> 1.18.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      # applications: [:exirc],
      mod: {Starbridge.Application, []}
    ]
  end

  defp package do
    [
      licenses: ["AGPL-3.0-or-later"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    run_discord =
      File.read!(".env")
      |> String.contains?("DISCORD_ENABLED=true")

    [
      {:nostrum, "~> 0.10.4", runtime: run_discord},
      {:exirc, "~> 2.0.0"},
      {:dotenvy, "~> 1.1.0"},
      {:polyjuice_client, "~> 0.4.4"}
    ]
  end
end
