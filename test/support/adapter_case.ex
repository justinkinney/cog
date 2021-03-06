defmodule Cog.AdapterCase do
  alias ExUnit.CaptureLog
  alias Cog.Repo
  alias Cog.Bootstrap

  @vcr_adapter ExVCR.Adapter.IBrowse

  defmacro __using__([adapter: adapter]) do
    {:ok, adapter_module} = Cog.chat_adapter_module(String.downcase(adapter))
    adapter_helper = Module.concat([adapter_module, "Helpers"])

    quote do
      use ExUnit.Case, async: false
      import unquote(adapter_helper)
      import unquote(__MODULE__)
      import Cog.Support.ModelUtilities
      import ExUnit.Assertions
      import Cog.AdapterAssertions

      setup_all do
        adapter = replace_adapter(unquote(adapter))

        Ecto.Adapters.SQL.begin_test_transaction(Repo)

        on_exit(fn ->
          Ecto.Adapters.SQL.rollback_test_transaction(Repo)
          reset_adapter(adapter)
        end)

        :ok
      end

      setup context do
        recorder = start_recorder(unquote(adapter), context)

        Ecto.Adapters.SQL.restart_test_transaction(Repo, [])
        bootstrap
        Cog.Command.PermissionsCache.reset_cache

        on_exit(fn ->
          stop_recorder(recorder)
        end)

        :ok
      end

    end
  end

  # If we are using the test adapter, we do nothing
  def replace_adapter("test"),
    do: Application.get_env(:cog, :adapter)
  def replace_adapter(new_adapter) do
    adapter = Application.get_env(:cog, :adapter)
    Application.put_env(:cog, :adapter, new_adapter)
    restart_application
    adapter
  end

  def reset_adapter(adapter) do
    Application.put_env(:cog, :adapter, adapter)
    restart_application
  end

  def restart_application do
    CaptureLog.capture_log(fn ->
      Application.stop(:cog)
      Application.start(:cog)
    end)
  end

  def bootstrap do
    without_logger(fn ->
      Bootstrap.bootstrap
    end)
  end

  def without_logger(fun) do
    Logger.disable(self)
    fun.()
    Logger.enable(self)
  end

  # The following recorder functions were adapted from ExVCR's `use_cassette`
  # function which could not be easily used here.
  def start_recorder("test", _context), do: nil
  def start_recorder(_adapter, context) do
    fixture = ExVCR.Mock.normalize_fixture("#{context.case}.#{context.test}")
    recorder = ExVCR.Recorder.start(fixture: fixture, adapter: @vcr_adapter, match_requests_on: [:query, :request_body])

    ExVCR.Mock.mock_methods(recorder, @vcr_adapter)

    recorder
  end

  def stop_recorder(nil), do: nil
  def stop_recorder(recorder) do
    try do
      :meck.unload(@vcr_adapter.module_name)
    after
      ExVCR.Recorder.save(recorder)
    end
  end
end
