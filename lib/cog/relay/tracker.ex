defmodule Cog.Relay.Tracker do
  require Logger

  alias Cog.Models.Bundle

  @moduledoc """
  Represents the internal state of `Cog.Relay.Relays` and functions to
  operate on it.

  Tracks all the relays that have checked in with the bot, recording
  which bundles they each serve.

  Maintains a set of disabled relays. Relays that appear in the disabled
  set will be filtered out when the list of relays for a bundle is requested.
  Note: Relays must be explicitly disabled, otherwise they are assumed to be
  available.
  """

  @type t :: %__MODULE__{map: %{String.t => MapSet.t},
                         disabled: MapSet.t}
  defstruct [map: %{}, disabled: MapSet.new]

  @doc """
  Create a new, empty Tracker
  """
  @spec new() :: t
  def new(),
    do: %__MODULE__{}

  @doc """
  Enables a relay if it exists in the disabled set by removing it from the
  disabled set. When the list of relays for a bundle is requested, disabled
  bundles are filtered out.

  Note: If a relay is assigned no bundles it is unknown to the tracker. When
  enabling or disabling make sure to load bundles first or this will just be
  a noop.
  """
  @spec enable_relay(t, String.t) :: t
  def enable_relay(tracker, relay_id) do
    disabled = MapSet.delete(tracker.disabled, relay_id)
    %{tracker | disabled: disabled}
  end

  @doc """
  Disables a relay if it exists in the tracker by adding it to the disabled
  set. When the list of relays for a bundle is requested, disabled bundles
  are filtered out.

  Note: If a relay is assigned no bundles it is unknown to the tracker. When
  enabling or disabling make sure to load bundles first or this will just be
  a noop.
  """
  @spec disable_relay(t, String.t) :: t
  def disable_relay(tracker, relay_id) do
    if in_tracker?(tracker, relay_id) do
      disabled = MapSet.put(tracker.disabled, relay_id)
      %{tracker | disabled: disabled}
    else
      tracker
    end
  end

  @doc """
  Removes all record of `relay` from the tracker. If `relay` is the
  last one serving a given bundle, that bundle is removed from the
  tracker as well.
  """
  @spec remove_relay(t, String.t) :: t
  def remove_relay(tracker, relay) do
    updated = Enum.reduce(tracker.map, %{}, fn({bundle, relays}, acc) ->
      remaining = MapSet.delete(relays, relay)
      if Enum.empty?(remaining) do
        acc
      else
        Map.put(acc, bundle, remaining)
      end
    end)

    disabled = MapSet.delete(tracker.disabled, relay)
    %{tracker | map: updated, disabled: disabled}
  end

  @doc """
  Records `relay` as serving each of `bundles`. If `relay` has
  previously been recorded as serving other bundles, those bundles are
  retained; this is an incremental, cumulative operation.
  """
  @spec add_bundles_for_relay(t, String.t, [%Bundle{}]) :: t
  def add_bundles_for_relay(tracker, relay, bundles) do
    map = Enum.reduce(bundles, tracker.map, fn(bundle, acc) ->
      Map.update(acc, bundle.name, MapSet.new([relay]), &MapSet.put(&1, relay))
    end)
    %{tracker | map: map}
  end

  @doc """
  Like `add_bundles_for_relay/3` but overwrites any existing bundle
  information for `relay`. From this point, `relay` is known to only
  serve `bundles`, and no others.
  """
  @spec set_bundles_for_relay(t, String.t, [%Bundle{}]) :: t
  def set_bundles_for_relay(tracker, relay, bundles) do
    tracker
    |> remove_relay(relay)
    |> add_bundles_for_relay(relay, bundles)
  end

  @doc """
  Removes the given bundle from the tracker.
  """
  @spec drop_bundle(t, String.t) :: t
  def drop_bundle(tracker, bundle_name) do
    map = Map.delete(tracker.map, bundle_name)
    %{tracker | map: map}
  end

  @doc """
  Return a list of relays serving `bundle_name`. If the bundle is
  disabled, return an empty list.
  """
  @spec relays(t, String.t) :: [String.t]
  def relays(tracker, bundle_name) do
    tracker.map
    |> Map.get(bundle_name, MapSet.new)
    |> MapSet.difference(tracker.disabled)
    |> MapSet.to_list
  end

  defp in_tracker?(tracker, relay_id) do
    Map.values(tracker.map)
    |> Enum.reduce(&MapSet.union(&1, &2))
    |> MapSet.member?(relay_id)
  end
end
