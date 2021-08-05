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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      dep(:govee_semaphore, :github),
      dep(:scenic, :github)
    ]
  end

  defp dep(:govee_semaphore, :github), do: {:govee_semaphore, github: "axelson/govee_semaphore"}
  defp dep(:govee_semaphore, :path), do: {:govee_semaphore, path: "~/dev/govee_semaphore"}

  defp dep(:scenic, :hex), do: {:scenic, "~> 0.10"}

  defp dep(:scenic, :github),
    do: {:scenic, github: "boydm/scenic", ref: "d47a82c", override: true}

  defp dep(:scenic, :path), do: {:scenic, path: "../forks/scenic", override: true}
end
