defmodule Starbridge.Logger do
  require Logger

  def log(level, provider, message) do
    Logger.log(level, provider <> " " <> message)
  end

  defmacro resolve_caller do
    quote do
      {caller_mod, _calling_func, _calling_func_arity, [file: _file, line: _line]} =
        Process.info(self(), :current_stacktrace) |> elem(1) |> Enum.fetch!(1)

      caller_mod
        |> Atom.to_string()
        |> String.split(".")
        |> Enum.at(-1)
    end
  end

  defmacro provider do
    quote do
      "\t[*BRIDGE : #{Starbridge.Logger.resolve_caller()}]"
    end
  end

  defmacro debug(message) do
    quote do
      Starbridge.Logger.log(:debug, Starbridge.Logger.provider, unquote(message))
    end
  end

  defmacro info(message) do
    quote do
      Starbridge.Logger.log(:info, Starbridge.Logger.provider, unquote(message))
    end
  end

  defmacro warn(message) do
    quote do
      Starbridge.Logger.log(:warning, Starbridge.Logger.provider, unquote(message))
    end
  end

  defmacro error(message) do
    quote do
      Starbridge.Logger.log(:error, Starbridge.Logger.provider, unquote(message))
    end
  end

  defmacro notice(message) do
    quote do
      Starbridge.Logger.log(:notice, Starbridge.Logger.provider, unquote(message))
    end
  end
end
