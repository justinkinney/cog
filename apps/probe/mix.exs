defmodule Probe.Mixfile do
  use Mix.Project

  def project do
    [app: :probe,
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
    [applications: [:logger],
     mod: {Probe, []}]
  end

  defp deps do
    [{:ex_doc, "~> 0.11.4", only: :dev},
     {:earmark, "~> 0.2.1", only: :dev},
     {:mix_test_watch, "~> 0.2.5", only: :dev}]
  end
end
