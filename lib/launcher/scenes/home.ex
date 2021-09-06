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
    :ok = GoveeSemaphore.subscribe()
    %Scenic.ViewPort{size: {screen_width, screen_height}} = scene.viewport

    Logger.debug("init!")
    message = get_message()

    graph =
      Graph.build()
      # Rectangle used for capturing input for the scene
      |> Scenic.Primitives.rect({screen_width, screen_height})
      |> Scenic.Components.button("Sleep Screen",
        id: :btn_sleep_screen,
        t: {10, screen_height - 70},
        button_font_size: @button_font_size
      )
      |> Scenic.Components.button("Reboot",
        id: :btn_reboot,
        t: {255, screen_height - 70},
        button_font_size: @button_font_size
      )
      |> Scenic.Components.button("Exit",
        id: :btn_exit,
        t: {424, screen_height - 70},
        button_font_size: @button_font_size
      )
      |> Scenic.Primitives.text("message: #{message}",
        id: :note_text,
        t: {250, 10},
        font_size: 34,
        text_align: :left,
        text_base: :top
      )
      |> Scenic.Components.button("Clear Message",
        id: :btn_clear_message,
        t: {240, 100},
        button_font_size: @button_font_size
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
        button_font_size: @button_font_size
      )
    end)
  end

  defp button_id(slug), do: "btn_scene_#{slug}"

  @impl Scenic.Scene
  def handle_input({:key, {_, :press, _}}, _context, scene) do
    state = scene.assigns.state

    state =
      case scene.assigns.state do
        %State{sleep: true} -> unsleep_screen(state)
        _ -> state
      end

    scene =
      scene
      |> assign(:state, state)

    {:noreply, scene}
  end

  def handle_input({:cursor_button, {_, :press, _, _}}, _context, scene) do
    state = scene.assigns.state

    state =
      case scene.assigns.state do
        %State{sleep: true} -> unsleep_screen(state)
        _ -> state
      end

    scene =
      scene
      |> assign(:state, state)

    {:noreply, scene}
  end

  def handle_input(_input, _context, scene) do
    # Logger.info("ignoring input: #{inspect input}. Scene: #{inspect scene}")
    {:noreply, scene}
  end

  @impl GenServer
  def handle_info(:refresh, scene) do
    schedule_refresh()
    scene = push_graph(scene, scene.assigns.state.graph)
    {:noreply, scene}
  end

  def handle_info({:govee_semaphore, :submit_note, note}, scene) do
    state = scene.assigns.state

    message =
      case note do
        :empty -> "empty note"
        _ -> note
      end

    graph =
      state.graph
      |> Graph.modify(:note_text, &Scenic.Primitives.text(&1, "message: #{message}", []))

    state = %State{state | graph: graph}

    scene =
      scene
      |> assign(:state, state)

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
    state = scene.assigns.state
    state = sleep_screen(state)

    scene =
      scene
      |> assign(:state, state)

    {:halt, scene}
  end

  def handle_event({:click, :btn_exit}, _from, scene) do
    exit()
    {:halt, scene}
  end

  def handle_event({:click, :btn_clear_message}, _from, scene) do
    GoveeSemaphore.clear_note()
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

  defp schedule_refresh do
    if Launcher.LauncherConfig.refresh_enabled?() do
      Process.send_after(self(), :refresh, @refresh_rate)
    end
  end

  defp backlight(), do: Launcher.LauncherConfig.backlight_module()

  defp reboot do
    case Launcher.LauncherConfig.reboot_mfa() do
      nil -> Logger.info("No reboot mfa set")
      {mod, fun, args} -> apply(mod, fun, args)
    end
  end

  defp get_message do
    if Process.whereis(GoveeSemaphore) do
      GoveeSemaphore.get_note()
    end
  end

  defp exit do
    :application.stop(:play)
  end
end
