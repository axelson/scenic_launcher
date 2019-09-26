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
  alias Scenic.ViewPort

  @width 30
  @height 30

  defmodule State do
    defstruct [:viewport, :on_switch]
  end

  @impl Scenic.Component
  def verify(data), do: {:ok, data}

  @impl Scenic.Scene
  def init(opts, scenic_opts) do
    on_switch = Keyword.get(opts, :on_switch)
    viewport = scenic_opts[:viewport]
    {:ok, %{size: {screen_width, _screen_height}}} = ViewPort.info(viewport)

    graph =
      Graph.build()
      |> Scenic.Primitives.rect({@width, @height}, fill: :clear, t: {screen_width - @width, 0})

    state = %State{viewport: viewport, on_switch: on_switch}

    {:ok, state, push: graph}
  end

  @impl Scenic.Scene
  def handle_input({:cursor_button, {_, :press, _, _}}, _context, state) do
    if state.on_switch, do: state.on_switch.()
    Launcher.switch_to_launcher(state.viewport)
    {:noreply, state}
  end

  def handle_input(_input, _context, state) do
    {:noreply, state}
  end
end
