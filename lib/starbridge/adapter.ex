defmodule Starbridge.Adapter do
  defmacro __using__(_) do
    quote do
      @behaviour Starbridge.Adapter

      def enabled do
        false
      end

      def state do
        %{}
      end

      def child do
        __MODULE__
      end

      defoverridable Starbridge.Adapter
    end
  end

  @callback enabled() :: boolean()
  @callback state() :: map()
  @callback child() :: atom()
end
