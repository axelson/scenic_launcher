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
      {:scenic, "~> 0.10"},
    ]
  end

  defp dep(:govee_semaphore, :github), do: {:govee_semaphore, github: "axelson/govee_semaphore"}
  defp dep(:govee_semaphore, :path), do: {:govee_semaphore, path: "~/dev/govee_semaphore"}
end
