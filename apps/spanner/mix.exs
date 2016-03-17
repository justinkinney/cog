defmodule Spanner.Mixfile do
  use Mix.Project

  def project do
    [app: :spanner,
     version: "0.2.0",
     build_path: "../../_build",
     config_path: "config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger,
                    :yaml_elixir,
                    :porcelain]]
  end

  defp deps do
    [{:piper, in_umbrella: true},
     {:carrier, in_umbrella: true},

     # For yaml parsing. yaml_elixir is a wrapper around yamerl which is a native erlang lib.
     {:yaml_elixir, "~> 1.0.0"},
     {:yamerl, github: "yakaz/yamerl"},

     {:ex_json_schema, "~> 0.3.1"},
     {:porcelain, "~> 2.0.1"}]
  end
end
