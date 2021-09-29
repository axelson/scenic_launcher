defmodule ScenicContrib.Utils do
  defmacro input_state(:press) do
    quote do
      1
    end
  end

  defmacro input_state(:release) do
    quote do
      0
    end
  end

  defmacro input_state(:repeat) do
    quote do
      2
    end
  end

  defmacro add_log_input do
    quote do
      def handle_input(input, _context, scene) do
        require Logger
        Logger.warn("#{__MODULE__} ignoring input: #{inspect(input)}")
        {:noreply, scene}
      end
    end
  end
end
