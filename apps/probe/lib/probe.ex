defmodule Probe do
  @moduledoc """
  Main interface to the Probe event manager.
  """
  use Application
  require Logger

  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    Logger.info("Starting #{inspect __MODULE__}")
    Supervisor.start_link([worker(Probe.EventManager, [])],
                          [strategy: :one_for_one, name: __MODULE__])
  end

  @doc """
  Send an event to be logged.
  """
  def notify(event),
    do: GenEvent.sync_notify(Probe.EventManager, event)

end
