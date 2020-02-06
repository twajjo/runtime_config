defmodule Runtime.Config do
  @moduledoc """
  Uses Config.Helper to get properly typed Elixir values.

  Leverages [BradleyD's external config loader](https://github.com/bradleyd/external_config)

  Add `external_config` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:external_config, "~> 0.1.0"}]
    end
    ```

  After calling load_runtime_config(application), runtime settings will be available using Application module functions, just as
  though the values were set during compile time, although they are runtime values read from the ENV values.
  """
  require Logger

  @doc """
  """
  def load_runtime_config(application) do
    config_path(application)
    |> ExternalConfig.read!()
    |> Keyword.fetch!(application)
    |> update_logging_level()
    #    |> IO.inspect(label: "Runtime configuration")
    |> Enum.each(fn {key, value} -> Application.put_env(application, key, value) end)
  end

  defp config_path(application) do
    # Support both absolute and relative paths in the configuration.
    Application.fetch_env!(application, :runtime_config_file)
    |> (fn config_file ->
          (String.starts_with?(config_file, "/") && config_file) ||
            Path.join(File.cwd!(), config_file)
        end).()
  end

  defp update_logging_level(config) do
    Logger.debug("Changing logging level to #{Keyword.get(config, :logging_level, nil)}")
    update_logging_level(Logger.level(), Keyword.get(config, :logging_level, nil))
    config
  end
  defp update_logging_level(from, level) when level in [:debug, :info, :warn, :error] do
    Logger.debug("Changing logging level from #{inspect(from)} to #{inspect(level)}")
    Logger.configure_backend(:console, level: level)
  end
  defp update_logging_level(_, _) do
  end
end
