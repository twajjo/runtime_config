use ExternalConfig

alias Runtime.Config.Helper
# include aliases to custom types or structs here...

config :runtime_config,
  logging_level:
    Helper.get_env(
      "LOGGING_LEVEL",
      type: :atom,
      default: :info,
      in_set: [:debug, :info, :warn, :error]
    )
