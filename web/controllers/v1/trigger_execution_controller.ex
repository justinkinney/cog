defmodule Cog.V1.TriggerExecutionController do
  use Cog.Web, :controller

  import Cog.Plug.Util, only: [get_request_id: 1,
                               get_user: 1,
                               set_user: 2]

  require Logger

  alias Cog.Plug.Authentication

  alias Cog.Models.User
  alias Cog.Models.Trigger
  alias Cog.Repository.Triggers
  alias Cog.Adapters.Http.AdapterBridge

  plug :parse

  def execute_trigger(conn, %{"id" => trigger_id}) do
    case Triggers.trigger_definition(trigger_id) do
      {:ok, %Trigger{enabled: true}=trigger} ->
        conn = resolve_user(conn, trigger)
        case get_user(conn) do
          %User{username: as_user} ->

            conn = Plug.Conn.fetch_query_params(conn)
            request_id = get_request_id(conn)
            timeout    = computed_timeout(trigger)

            context = %{trigger_id: trigger_id,
                        headers: headers_to_map(conn.req_headers),
                        query_params: conn.query_params,
                        raw_body: get_raw_body(conn),
                        body: get_parsed_body(conn)}

            requestor = requestor_map(trigger_id, as_user, trigger.name)

            case AdapterBridge.submit_request(requestor, request_id, context, trigger.pipeline, timeout) do
              %{"status" => "ok"} ->
                conn |> send_resp(:no_content, "")
              {:error, :timeout} ->
                conn
                |> put_status(:accepted)
                |> json(%{status: "Request accepted and still processing after #{trigger.timeout_sec} seconds",
                          id: request_id})
              response ->
                # TODO: FIIIIIIIIILTHY HACK
                # Until we have proper error templates, the easiest
                # way to distinguish errors from success is to see if
                # the response "looks like an error".
                if is_binary(response) && String.contains?(response, "An error has occurred") do
                  conn |> put_status(:internal_server_error) |> json(%{errors: response})
                else
                  conn |> put_status(:ok) |> json(response)
                end
            end
          nil ->
            # Don't know which user to run this as, but the response
            # will have already been set, so pass it on out. See
            # resolve_user/2 below
            conn
        end
      {:ok, %Trigger{enabled: false}} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: "Trigger is not enabled"})
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Trigger not found"})
      {:error, :bad_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: "Bad ID format"})
    end
  end

  ########################################################################

  # This is the requestor map that will eventually make its way into
  # the executor and subsequently to commands. It's how we'll expose
  # trigger metadata to commands, for instance.
  defp requestor_map(trigger_id, trigger_user, trigger_name) do
    %{id: trigger_user,
      trigger_user: trigger_user,
      trigger_id: trigger_id,
      trigger_name: trigger_name}
  end

  # Convert a header list into a map, accumulating multiple values
  # into lists. Single values remain as single values.
  defp headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn({k,v}, acc) ->
      case Map.fetch(acc, k) do
        :error ->
          Map.put(acc, k, v)
        multiple when is_list(multiple) ->
          Map.put(acc, k, Enum.concat(multiple,[v]))
        single ->
          Map.put(acc, k, [single, v])
      end
    end)
  end

  # If a trigger specifies a user, we use that. If it doesn't, we require
  # an authentication token; the trigger will execute as that user that
  # ownd the token
  defp resolve_user(conn, trigger) do
    case trigger.as_user do
      username when is_binary(username)->
        case Cog.Repo.get_by(User, username: username) do
          %User{}=user ->
            set_user(conn, user)
          nil ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: "Configured trigger user does not exist"})
        end
      nil ->
        Authentication.call(conn, Authentication.init(:argument_ignored))
    end
  end

  # In order to preserve the ability for pipelines to perform request
  # verification, we need to keep both the raw body (which is usually
  # what is cryptographically hashed with a user-provided secret) as
  # well as the JSON-parsed body (to allow easy variable binding in
  # pipelines, and not require manual JSON parsing).
  #
  # Unfortunately, that means we need to do the parsing ourselves
  # instead of relying on Phoenix's Plug.Parsers.JSON, which consumes
  # the raw body and doesn't make it available afterward.
  #
  # See https://hexdocs.pm/plug/1.1.3/Plug.Conn.html#read_body/2 for
  # details.
  defp parse(conn, []) do
    {:ok, raw_body, conn} = read_body(conn)
    parsed_body = case raw_body do
                    "" ->
                      {:ok, %{}}
                    _ ->
                      Poison.decode(raw_body)
                  end

    case parsed_body do
      {:ok, parsed} ->
        conn
        |> set_raw_body(raw_body)
        |> set_parsed_body(parsed)
      {:error, _} ->
        conn
        |> put_status(:unsupported_media_type)
        |> halt
    end
  end

  defp set_raw_body(conn, raw_body),
    do: assign(conn, :raw_body, raw_body)

  defp get_raw_body(conn),
    do: conn.assigns[:raw_body]

  defp set_parsed_body(conn, parsed_body),
    do: assign(conn, :parsed_body, parsed_body)

  defp get_parsed_body(conn),
    do: conn.assigns[:parsed_body]

  ########################################################################

  defp computed_timeout(%Trigger{timeout_sec: timeout_sec}) do
    case Application.get_env(:cog, :trigger_timeout_buffer) do
      slack when slack <= timeout_sec ->
        (timeout_sec - slack) * 1000
      _ ->
        0
    end
  end
end
