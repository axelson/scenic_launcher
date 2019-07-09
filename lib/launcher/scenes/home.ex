defmodule Launcher.Scene.Home do
  @moduledoc """
  The main home screen for the launcher. Provides a place to launch other
  activities from along with access to common features.
  """

  use Scenic.Scene
  require Logger
  alias Scenic.Graph
  alias Scenic.ViewPort

  defmodule State do
    @moduledoc false
    defstruct [:viewport, sleep: false]
  end

  @impl Scenic.Scene
  def init(_, scenic_opts) do
    state = %State{viewport: scenic_opts[:viewport]}
    {:ok, %ViewPort.Status{size: {screen_width, screen_height}}} = ViewPort.info(state.viewport)

    graph =
      Graph.build()
      # Rectangle used for capturing input for the scene
      |> Scenic.Primitives.rect({screen_width, screen_height})
      |> Scenic.Components.button("Asteroids", id: :btn_start_asteroids, t: {10, 10})
      |> Scenic.Components.button("Pomodoro", id: :btn_start_pomodoro, t: {10, 60})
      |> Scenic.Components.button("Sleep Screen",
        id: :btn_sleep_screen,
        t: {10, screen_height - 50}
      )
      |> Scenic.Components.button("Reboot", id: :btn_reboot, t: {150, screen_height - 50})

    {:ok, state, push: graph}
  end

  @impl Scenic.Scene
  def handle_input({:key, {_, :press, _}}, _context, %State{sleep: true} = state) do
    state = unsleep_screen(state)
    {:noreply, state}
  end

  def handle_input({:cursor_button, {_, :press, _, _}}, _context, %State{sleep: true} = state) do
    state = unsleep_screen(state)
    {:noreply, state}
  end

  def handle_input(_input, _context, state) do
    # Logger.info("ignoring input: #{inspect input}. State: #{inspect state}")
    {:noreply, state}
  end

  @impl Scenic.Scene
  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, :btn_start_asteroids}, _from, state) do
    launch_asteroids(state.viewport)
    {:halt, state}
  end

  def filter_event({:click, :btn_start_pomodoro}, _from, state) do
    launch_pomodoro(state.viewport)
    {:halt, state}
  end

  def filter_event({:click, :btn_reboot}, _from, state) do
    reboot()
    {:halt, state}
  end

  def filter_event({:click, :btn_sleep_screen}, _from, state) do
    state = sleep_screen(state)
    {:halt, state}
  end

  def filter_event(event, _from, state) do
    # IO.inspect(event, label: "event")
    {:cont, event, state}
  end

  defp launch_asteroids(viewport) do
    ViewPort.set_root(viewport, {Play.Scene.Splash, Play.Scene.Asteroids})
  end

  defp launch_pomodoro(viewport) do
    ViewPort.set_root(viewport, {Timer.Scene.Home, nil})
  end

  defp sleep_screen(state) do
    Logger.info("Sleeping screen")
    backlight = backlight()

    if backlight do
      backlight.brightness(0)
    end

    %{state | sleep: true}
  end

  defp unsleep_screen(state) do
    Logger.info("Unsleeping screen")
    backlight = backlight()

    if backlight do
      backlight.brightness(255)
    end

    %{state | sleep: false}
  end

  defp backlight(), do: Launcher.LauncherConfig.backlight_module()

  defp reboot do
    case Launcher.LauncherConfig.reboot_mfa() do
      nil -> Logger.info("No reboot mfa set")
      {mod, fun, args} -> apply(mod, fun, args)
    end
  end
end
