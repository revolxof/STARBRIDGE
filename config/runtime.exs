import Config
import Dotenvy

source!([".env", System.get_env()])

config :nostrum,
  token: env!("DISCORD_TOKEN", :string),
  gateway_intents: [
    :guild_messages,
    :message_content
  ]

config :starbridge,
  recast_path: env!("RECAST_PATH", :string, ".recast"),
  display: env!("DISPLAY_STRING", :string, "<$author $channel @ $server> $content"),
  irc_enabled: env!("IRC_ENABLED", :string, "false"),
  discord_enabled: env!("DISCORD_ENABLED", :string, "false"),
  matrix_enabled: env!("MATRIX_ENABLED", :string, "false"),

  irc_address: env!("IRC_ADDRESS", :string),
  # complains when nil, error in ExIRC
  irc_password: env!("IRC_PASSWORD", :string, ""),
  irc_port: env!("IRC_PORT", :integer, 6667),
  irc_nickname: env!("IRC_NICKNAME", :string, "STARBRIDGE"),
  irc_username: env!("IRC_USERNAME", :string, "STARBRIDGE"),
  irc_realname: env!("IRC_REALNAME", :string, "*BRIDGE"),

  discord_status: env!("DISCORD_STATUS", :string, nil),
  discord_status_type: env!("DISCORD_STATUS_TYPE", :atom, :playing),

  matrix_address: env!("MATRIX_ADDRESS", :string),
  matrix_token: env!("MATRIX_TOKEN", :string),
  matrix_user: env!("MATRIX_USER", :string),

  recasts:
    File.read!(env!("RECAST_PATH", :string, ".recast"))
    |> Starbridge.Recast.parse_recast()
