defmodule Probe.Configuration do
  require Logger
  require Probe.ConfigurationError

  alias Probe.ConfigurationError

  @doc """
  Returns the absolute path to the configured root directory for
  Probe's logs (`:probe/:log_directory`). Defaults to `audit_logs` in
  the current directory.
  """
  def log_directory,
    do: Path.absname(Application.get_env(:probe, :log_directory, "audit_logs"))

  @doc """
  Raises a `Probe.ConfigurationError` if the log directory exists and
  is not a directory, or if it cannot be created.

  Does _not_ perform any checks that the directory can be written to.
  """
  def ensure_log_directory! do
    dir = log_directory
    if File.exists?(dir) do
      if File.dir?(dir) do
        :ok
      else
        raise ConfigurationError.new("Configured audit log directory `#{dir}` is not a directory!")
      end
    else
      Logger.warn("Audit log directory `#{dir}` does not exist; attempting to create it now")
      case File.mkdir_p(dir) do
        :ok ->
          Logger.info("Successfully created audit log directory `#{dir}`")
        error ->
          raise ConfigurationError.new("Could not create audit log directory `#{dir}`: #{inspect error}")
      end
    end
    Logger.info("Writing audit logs to the `#{dir}` directory")
    :ok
  end

end
