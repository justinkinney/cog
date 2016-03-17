defmodule Probe.JSONLogHandler do
  @moduledoc """
  Logs events as structured JSON maps to a file. Designed to work with
  log rotation utilities, tolerating the log file being moved or
  deleted from underneath it.
  """

  use GenEvent
  require Logger

  alias Probe.TolerantFile

  @log_file "events.log"

  # If we can't log, then we don't run, and we'll shut down the VM
  # with this code.
  @exit_code 10

  @type state :: %__MODULE__{log_file: Probe.TolerantFile.t}
  defstruct [log_file: nil]

  def init(_) do
    path = log_path
    Logger.info("Attempting to open JSON-formatted event log file `#{path}`")
    case TolerantFile.open(path) do
      {:ok, file} ->
        Logger.info("Logging JSON-formatted event stream to `#{path}`")
        {:ok, %__MODULE__{log_file: file}}
      {:error, _}=error ->
        Logger.error("Could not open JSON event log file `#{path}`: #{inspect error}")
        error
    end
  end

  def handle_event(event, state) when is_map(event) do
    case Poison.encode(event) do
      {:ok, json} ->
        handle_event(json, state)
      error ->
        Logger.error("Could not encode event as JSON: `#{inspect event}`; error: #{inspect error}")
        {:ok, state}
    end
  end
  def handle_event(event, state) when is_binary(event) do
    case TolerantFile.puts(state.log_file, event) do
      {:ok, log_file} ->
        {:ok, %{state | log_file: log_file}}
      error ->
        # Something happened and we couldn't write to the log
        # file. Since we're leaving an audit trail here, not being
        # able to write that trail is bad, so we slam down on the
        # self-destruct button to bring the entire VM down
        Logger.error("Could not write event to log file: #{inspect error}; shutting down the VM")
        :erlang.halt(@exit_code, [{:flush, true}])
    end
  end

  defp log_path,
    do: Path.join(Probe.Configuration.log_directory, @log_file)

end
