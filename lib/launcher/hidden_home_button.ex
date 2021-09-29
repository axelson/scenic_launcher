defmodule Launcher.HiddenHomeButton do
  @moduledoc """
  A transparent button that will switch back to the main launcher screen. Should
  be rendered last so that it is on the top and can be clicked/tapped.

  Example of adding the HiddenHomeButton to a graph

      graph
      |> Launcher.HiddenHomeButton.add_to_graph(on_switch: &on_switch_handler/0)

  Note that passing an `on_switch` callback function is optional but lets the
  scene respond to being switched away from (although perhaps there's better
  mechanisms to handle that)

  NOTE: HiddenHomeButton should be added to the scene last so that it is drawn
  on top of everything else and can receive the clicks in it's designated area.
  """
  use Scenic.Component, has_children: true

  alias Scenic.Graph

  @width 40
  @height 40

  defmodule State do
    defstruct [:on_switch]
  end

  @impl Scenic.Component
  def validate(data), do: {:ok, data}

  @impl Scenic.Scene
  def init(scene, opts, _scenic_opts) do
    on_switch = Keyword.get(opts, :on_switch)

    state = %State{on_switch: on_switch}

    scene =
      scene
      |> assign(:state, state)
      |> push_graph(graph(scene))

    if auto_refresh(), do: schedule_refresh()

    {:ok, scene}
  end

  @impl Scenic.Scene
  def handle_input({:cursor_button, {:btn_left, 1, _, _}}, _context, scene) do
    state = scene.assigns.state
    if state.on_switch, do: state.on_switch.()
    Launcher.switch_to_launcher(scene.viewport)
    {:noreply, scene}
  end

  def handle_input(_input, _context, scene) do
    {:noreply, scene}
  end

  @impl GenServer
  def handle_info(:refresh_tick, scene) do
    push_graph(scene, graph(scene))

    schedule_refresh()
    {:noreply, scene}
  end

  defp graph(scene) do
    %Scenic.ViewPort{size: {screen_width, _screen_height}} = scene.viewport
    {ms, _} = :erlang.statistics(:wall_clock)

    Graph.build()
    |> Scenic.Primitives.rect({@width, @height},
      input: [:cursor_button],
      fill: :clear,
      t: {screen_width - @width, 0}
    )
    |> Scenic.Primitives.rect({1, 1},
      fill: :clear,
      t: {rem(ms, 100), 0}
    )
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh_tick, 100)

  defp auto_refresh, do: Application.get_env(:launcher, :auto_refresh)
end
