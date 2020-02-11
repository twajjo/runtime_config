defmodule RuntimeConfig.MixProject do
  use Mix.Project

  def project do
    [
      app: :runtime_config,
      version: "0.1.0",
      elixir: "~> 1.9.4",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :external_config
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:external_config, "~> 0.1.0"},
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev},
      # ... and for testing:
      {:mox, "~> 0.5.1", only: :test},
      {:excoveralls, "~> 0.7", only: :test},
      # Code smell detectors
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      # Utilities
      {:atomic_map, "~> 0.8"},
      {:jason, "~> 1.1"},
#      {:debug_test_lib, git: "git:github.com/mkreyman/debug_test_lib"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

end
