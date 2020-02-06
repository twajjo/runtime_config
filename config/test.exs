use Mix.Config

config :logger, 
  level: :warn

config :runtime_config,
  runtime_config_file: "config/runtime.exs"

# Mox modules to mock (should only be in test.exs)
config :runtime_config,
  helper_system: Runtime.Config.Helper.System.Wrapper.Mock
