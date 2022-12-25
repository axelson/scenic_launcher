defmodule ScenicContrib.IconComponent do
  @moduledoc """
  Responsible for displaying an image, tracking clicks to it, and when clicked
  it displays an alternate image (depressed state)
  """

  use Scenic.Component, has_children: true
  use ScenicWidgets.GraphTools.Upsertable

  require Logger
  require ScenicContrib.Utils

  alias Scenic.Graph

  defmodule State do
    defstruct [
      :graph,
      :icon,
      :on_press_icon,
      :on_click,
      :width,
      :height,
      :parent_pid,
      depressed: false,
      pressed_time: nil
    ]
  end

  @default_width 100
  @default_height 100
  @minimum_press_time 150

  @impl Scenic.Component
  def validate(data), do: {:ok, data}

  @impl Scenic.Scene
  def init(scene, opts, _scenic_opts) do
    icon = Keyword.get(opts, :icon)
    on_press_icon = Keyword.get(opts, :on_press_icon)
    width = Keyword.get(opts, :width, @default_width)
    height = Keyword.get(opts, :height, @default_height)
    parent_pid = Keyword.get(opts, :parent_pid)

    on_click = Keyword.get(opts, :on_click)

    state = %State{
      icon: icon,
      on_press_icon: on_press_icon,
      on_click: on_click,
      width: width,
      height: height,
      parent_pid: parent_pid
    }

    graph = render(state, false)
    state = %State{state | graph: graph}

    scene =
      scene
      |> assign(:state, state)
      |> push_graph(graph)

    {:ok, scene}
  end

  @impl Scenic.Scene
  # Press
  def handle_input(
        {:cursor_button, {:btn_left, 1, _, _}},
        _context,
        %{assigns: %{state: %State{pressed_time: nil}}} = scene
      ) do
    state = scene.assigns.state
    %State{on_click: on_click} = state
    Logger.info("handling on_click in #{inspect(self())}")
    Task.start(fn -> on_click.(state.parent_pid) end)

    graph = render(state, true)
    state = %State{state | pressed_time: System.monotonic_time(:millisecond)}

    # I would've preferred to let these events bubble up to the MusicControls
    # component but {:cont, scene} here appears to be effectively ignored

    scene =
      scene
      |> assign(:state, state)
      |> push_graph(graph)

    {:noreply, scene}
  end

  # Release
  def handle_input({:cursor_button, {:btn_left, 0, _, _}}, _context, scene) do
    state = scene.assigns.state

    release_delay =
      case state do
        %State{pressed_time: nil} ->
          @minimum_press_time

        %State{pressed_time: pressed_time} ->
          now = System.monotonic_time(:millisecond)
          max(@minimum_press_time - (now - pressed_time), 0)
      end

    Process.send_after(self(), :release_button, release_delay)
    {:noreply, scene}
  end

  # ScenicContrib.Utils.add_log_input()

  def handle_input(_input, _context, scene) do
    {:noreply, scene}
  end

  @impl Scenic.Scene
  def handle_update(params, _opts, scene) do
    scene =
      ScenicContrib.Utils.GraphState.update_state_and_graph(scene, fn state, _graph ->
        state =
          Enum.reduce(params, state, fn
            {:icon, icon}, %State{} = state -> %State{state | icon: icon}
            _, %State{} = state -> state
          end)

        graph = render(state, false)
        {state, graph}
      end)

    {:noreply, scene}
  end

  @impl GenServer
  def handle_info(:release_button, scene) do
    state = scene.assigns.state
    graph = render(state, false)
    state = %State{state | pressed_time: nil}

    scene =
      scene
      |> assign(:state, state)
      |> push_graph(graph)

    {:noreply, scene}
  end

  def handle_info(_, scene), do: {:noreply, scene}

  defp render(state, depressed) do
    %State{icon: icon, on_press_icon: on_press_icon, width: width, height: height} = state

    fill =
      if depressed && on_press_icon do
        {:image, on_press_icon}
      else
        {:image, icon}
      end

    # TODO: Don't rebuild a completely new graph here
    Graph.build()
    |> Scenic.Primitives.rect(
      {width, height},
      fill: fill,
      id: :icon_component,
      input: [:cursor_button]
    )
  end
end
