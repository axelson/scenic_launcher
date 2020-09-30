defmodule Launcher.Scene.Home do
  @moduledoc """
  The main home screen for the launcher. Provides a place to launch other
  activities from along with access to common features.
  """

  use Scenic.Scene
  require Logger
  alias Scenic.Graph
  alias Scenic.ViewPort

  @button_font_size 35
  @refresh_rate round(1_000 / 30)

  defmodule State do
    @moduledoc false
    defstruct [:viewport, :graph, sleep: false]
  end

  def config do
    Application.get_env(:launcher, :scenes, [])
  end

  @impl Scenic.Scene
  def init(_, scenic_opts) do
    :ok = GoveeSemaphore.subscribe()
    viewport = scenic_opts[:viewport]
    {:ok, %ViewPort.Status{size: {screen_width, screen_height}}} = ViewPort.info(viewport)

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
        text_align: :left_top
      )
      |> Scenic.Components.button("Clear Message",
        id: :btn_clear_message,
        t: {240, 100},
        button_font_size: @button_font_size
      )
      |> add_buttons_to_graph()

    schedule_refresh()

    state = %State{viewport: viewport, graph: graph}

    {:ok, state, push: graph}
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
  def handle_info(:refresh, state) do
    schedule_refresh()
    {:noreply, state, push: state.graph}
  end

  def handle_info({:govee_semaphore, :submit_note, note}, state) do
    message =
      case note do
        :empty -> "empty note"
        _ -> note
      end

    graph =
      state.graph
      |> Graph.modify(:note_text, &Scenic.Primitives.text(&1, "message: #{message}", []))

    state = %State{state | graph: graph}

    {:noreply, state, push: state.graph}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, "btn_scene_" <> slug}, _from, state) do
    %State{viewport: viewport} = state

    case scene_args(slug) do
      nil ->
        raise "Unable to find scene #{slug}"

      scene_args ->
        ViewPort.set_root(viewport, scene_args)
        {:halt, state}
    end
  end

  def filter_event({:click, :btn_reboot}, _from, state) do
    reboot()
    {:halt, state}
  end

  def filter_event({:click, :btn_sleep_screen}, _from, state) do
    state = sleep_screen(state)
    {:halt, state}
  end

  def filter_event({:click, :btn_exit}, _from, state) do
    exit()
    {:halt, state}
  end

  def filter_event({:click, :btn_clear_message}, _from, state) do
    GoveeSemaphore.clear_note()
    {:halt, state}
  end

  def filter_event(event, _from, state) do
    # IO.inspect(event, label: "event")
    {:cont, event, state}
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
