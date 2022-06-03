defmodule ConfigTuples.Error do
  @moduledoc """
  Error custom exception for ConfigTuples provider
  """

  defexception [:message, :reason]

  def exception(msg) when is_binary(msg) do
    %__MODULE__{message: msg, reason: nil}
  end

  def exception({:error, reason}) do
    %__MODULE__{message: format_reason(reason), reason: reason}
  end

  def message(%__MODULE__{message: message}) do
    message
  end

  defp format_reason({:required, env_value}),
    do: "environment variable '#{env_value}' required but is not set"

  defp format_reason(reason), do: "#{inspect(reason)}"
end
