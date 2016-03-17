defmodule Probe.EventManager do

  @doc """
  Starts the GenEvent manager and adds the `Probe.JSONLogHandler` to
  it.
  """
  def start_link() do
    Probe.Configuration.ensure_log_directory!
    {:ok, pid} = GenEvent.start_link(name: __MODULE__)
    :ok = GenEvent.add_handler(__MODULE__, Probe.JSONLogHandler, [])
    {:ok, pid}
  end

end
