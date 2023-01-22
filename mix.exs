defmodule Launcher.MixProject do
  use Mix.Project

  def project do
    [
      app: :launcher,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Launcher.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      dep(:scenic, :hex),
      {:scenic_live_reload, path: "~/dev/scenic_live_reload", only: :dev},
      {:exsync, path: "~/dev/forks/exsync", override: true, only: [:dev]},
      {:scenic_driver_local, "~> 0.11", only: :dev},
      {:scenic_widget_contrib, github: "axelson/scenic-widget-contrib", branch: "jax"}
      # {:scenic_widget_contrib, path: "~/dev/forks/scenic-widget-contrib"}
    ]
  end

  defp dep(:scenic, :hex), do: {:scenic, "~> 0.10"}

  defp dep(:scenic, :github),
    do: {:scenic, github: "boydm/scenic", branch: "v0.11", override: true}

  defp dep(:scenic, :path), do: {:scenic, path: "../forks/scenic", override: true}
end
