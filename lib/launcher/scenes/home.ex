defmodule Launcher.Scene.Home do
  @moduledoc """
  The main home screen for the launcher. Provides a place to launch other
  activities from along with access to common features.
  """

  use Scenic.Scene
  require Logger
  alias Scenic.Graph
  alias Scenic.ViewPort

  @button_font_size 30
  @refresh_rate round(1_000 / 30)

  defmodule State do
    @moduledoc false
    defstruct [:graph, sleep: false]
  end

  def config do
    Application.get_env(:launcher, :scenes, [])
  end

  @impl Scenic.Scene
  def init(scene, _args, _scenic_opts) do
    %Scenic.ViewPort{size: {screen_width, screen_height}} = scene.viewport

    Logger.debug("init!")

    graph =
      Graph.build()
      # Rectangle used for capturing input for the scene
      |> Scenic.Primitives.rect({screen_width, screen_height}, input: [:cursor_button])
      |> Scenic.Components.button("Sleep Screen",
        id: :btn_sleep_screen,
        t: {10, screen_height - 70},
        styles: [font_size: @button_font_size]
      )
      |> Scenic.Components.button("Sleep All",
        id: :btn_sleep_all,
        t: {255, screen_height - 70},
        styles: [font_size: @button_font_size]
      )
      |> Scenic.Components.button("Reboot",
        id: :btn_reboot,
        t: {444, screen_height - 70},
        styles: [font_size: @button_font_size]
      )
      |> Scenic.Components.button("Exit",
        id: :btn_exit,
        t: {680, screen_height - 70},
        styles: [font_size: @button_font_size]
      )
      |> add_buttons_to_graph()

    schedule_refresh()

    state = %State{graph: graph}

    scene =
      scene
      |> assign(:state, state)
      |> push_graph(graph)

    {:ok, scene}
  end

  defp add_buttons_to_graph(graph) do
    config()
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {app_config, index}, graph ->
      {slug, name, _} = app_config

      graph
      |> Scenic.Components.button(name,
        id: button_id(slug),
        t: {10, 10 + 80 * index},
        styles: [font_size: @button_font_size]
      )
    end)
  end

  defp button_id(slug), do: "btn_scene_#{slug}"

  @impl Scenic.Scene
  def handle_input({:key, {_, :press, _}}, _context, scene) do
    scene = maybe_unsleep_screen(scene)

    {:noreply, scene}
  end

  def handle_input({:cursor_button, {:btn_left, 1, _, _}}, _context, scene) do
    scene = maybe_unsleep_screen(scene)

    {:noreply, scene}
  end

  def handle_input(input, _context, scene) do
    Logger.info("ignoring input: #{inspect input}")
    {:noreply, scene}
  end

  @impl GenServer
  def handle_info(:refresh, scene) do
    schedule_refresh()
    scene = push_graph(scene, scene.assigns.state.graph)
    {:noreply, scene}
  end

  def handle_info(_, scene) do
    {:noreply, scene}
  end

  @impl Scenic.Scene
  def handle_event({:click, "btn_scene_" <> slug}, _from, scene) do
    state = scene.assigns.state

    case scene_args(slug) do
      nil ->
        raise "Unable to find scene #{slug}"

      {mod, args} ->
        ViewPort.set_root(scene.viewport, mod, args)
        {:halt, state}
    end
  end

  def handle_event({:click, :btn_reboot}, _from, scene) do
    reboot()
    {:halt, scene}
  end

  def handle_event({:click, :btn_sleep_screen}, _from, scene) do
    scene = sleep_screen(scene)

    {:halt, scene}
  end

  def handle_event({:click, :btn_sleep_all}, _from, scene) do
    scene = sleep_all(scene)
    {:halt, scene}
  end

  def handle_event({:click, :btn_exit}, _from, scene) do
    exit()
    {:halt, scene}
  end

  def handle_event(event, _from, scene) do
    # IO.inspect(event, label: "event")
    {:cont, event, scene}
  end

  defp scene_args(slug_to_find) do
    config()
    |> Enum.find_value(fn {slug, _name, scene_args} ->
      if slug == slug_to_find, do: scene_args
    end)
  end

  defp sleep_screen(scene) do
    state = scene.assigns.state
    %Scenic.ViewPort{size: {screen_width, screen_height}} = scene.viewport
    Logger.info("Sleeping screen")
    graph = state.graph
    backlight = backlight()

    if backlight do
      backlight.brightness(0)
    end

    # Add a rect that covers the whole screen so we can capture any tap and use
    # it to unsleep the screen
    graph =
      graph
      |> Scenic.Primitives.rect({screen_width, screen_height},
        id: :sleep_rect,
        input: [:cursor_button],
        # FIXME: This fill seems necessary for capturing the input which is not
        # expected to me
        fill: :black
      )

    state = %{state | sleep: true, graph: graph}

    scene =
      scene
      |> assign(:state, state)

    push_graph(scene, scene.assigns.state.graph)
  end

  defp sleep_all(scene) do
    sleep_all_module = sleep_all_module()

    if sleep_all_module do
      Logger.info("Sleep all with #{inspect(sleep_all_module)}!")
      sleep_all_module.sleep_all()
    end

    # Semi-synchronize the sleeping
    Process.sleep(300)

    sleep_screen(scene)
  end

  defp maybe_unsleep_screen(scene) do
    case scene.assigns.state do
      %State{sleep: true} -> unsleep_screen(scene)
      _ -> scene
    end
  end

  defp unsleep_screen(scene) do
    Logger.info("Unsleeping screen")
    state = scene.assigns.state
    backlight = backlight()
    graph = state.graph

    if backlight do
      backlight.brightness(255)
    end

    graph = Graph.delete(graph, :sleep_rect)

    state = %{state | sleep: false, graph: graph}

    scene =
      scene
      |> assign(:state, state)

    push_graph(scene, scene.assigns.state.graph)
  end

  defp schedule_refresh do
    if Launcher.LauncherConfig.refresh_enabled?() do
      Process.send_after(self(), :refresh, @refresh_rate)
    end
  end

  defp backlight(), do: Launcher.LauncherConfig.backlight_module()
  defp sleep_all_module(), do: Launcher.LauncherConfig.sleep_all_module()

  defp reboot do
    case Launcher.LauncherConfig.reboot_mfa() do
      nil -> Logger.info("No reboot mfa set")
      {mod, fun, args} -> apply(mod, fun, args)
    end
  end

  defp exit do
    :application.stop(:fw)
  end
end
