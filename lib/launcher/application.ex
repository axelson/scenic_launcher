defmodule Launcher.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        maybe_start_scenic()
      ]
      |> List.flatten()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: App.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_start_scenic do
    main_viewport_config = Application.get_env(:launcher, :viewport)

    if main_viewport_config do
      [
        {Scenic, [main_viewport_config]}
      ]
    else
      []
    end
  end
end
