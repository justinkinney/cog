defmodule Cog.Support.TestCommands.BadTemplate do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, name: "bad-template"

  def handle_message(req, state) do
    {:reply, req.reply_to, "badtemplate", %{bad: %{foo: "bar"}}, state}
  end
end

