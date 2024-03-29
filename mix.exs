# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.MixProject do
  use Mix.Project

  # Be sure to update generator/mix.exs when updating this file!

  @github_url "https://github.com/mathsaey/skitter/"
  @home_url "https://soft.vub.ac.be/~mathsaey/skitter/"

  def project do
    [
      app: :skitter,
      name: "Skitter",
      elixir: "~> 1.15",
      version: "0.6.4",
      source_url: @github_url,
      homepage_url: @home_url,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      dialyzer: dialyzer(),
      package: package(),
      deps: deps(),
      docs: docs(),
      xref: xref()
    ]
  end

  defp description do
    """
    A domain specific language for building scalable, distributed stream processing applications
    with custom distribution strategies.
    """
  end

  defp package do
    [
      licenses: ["MPL-2.0"],
      links: %{github: @github_url, homepage: @home_url}
    ]
  end

  defp deps do
    [
      # Dev
      {:credo, "~> 1.7", only: :dev, optional: true, runtime: false},
      {:ex_doc, "~> 0.29", only: :dev, optional: true, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, optional: true, runtime: false},

      # Runtime
      {:telemetry, "~> 1.2"},

      # Used by built-in strategies
      {:murmur, "~> 1.0"}
    ]
  end

  def application do
    [
      mod: {Skitter.Runtime.Application, []},
      start_phases: [sk_log: [], sk_welcome: [], sk_connect: [], sk_deploy: []],
      extra_applications: [:logger, :eex]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "generator/lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer do
    [
      plt_add_apps: [:mix, :iex, :eex],
      plt_local_path: "_build/dialyzer/"
    ]
  end

  defp xref do
    [exclude: IEx]
  end

  defp manual_pages do
    [
      Introduction: ~w(manual/overview.md manual/installation.md manual/up_and_running.md),
      Concepts: ~w(manual/workflows.md manual/operations.md manual/strategies.md manual/language_concepts.livemd),
      Deployment: ~w(manual/deployment.md manual/configuration.md),
      Guides: ~w(manual/operators.md manual/telemetry.md)
    ]
  end

  defp docs do
    [
      main: "overview",
      assets: "assets",
      formatters: ["html"],
      source_ref: "develop",
      authors: ["Mathijs Saey"],
      logo: "assets/logo-light_docs.png",
      before_closing_body_tag: &before_closing_body_tag/1,
      # Manual
      extra_section: "manual",
      extras: Enum.flat_map(manual_pages(), fn {_, pages} -> pages end),
      groups_for_extras: manual_pages(),
      # Module documentation
      api_reference: false,
      nest_modules_by_prefix: [Skitter.DSL, Skitter.BIO, Skitter.BIS],
      groups_for_modules: [
        "Language Abstractions": [
          Skitter.Operation,
          Skitter.Workflow,
          Skitter.Strategy
        ],
        "Runtime Hooks": ~r/Skitter.Strategy\..*/,
        "Runtime Constructs": [
          Skitter.Worker,
          Skitter.Deployment,
          Skitter.Remote,
          Skitter.Runtime
        ],
        dsl: ~r/Skitter.DSL*/,
        "Built-in Operations": ~r/Skitter.BIO.*/,
        "Built-in Strategies": ~r/Skitter.BIS.*/,
        utilities: [
          Skitter.Dot,
          Skitter.Config,
          Skitter.Telemetry,
          Skitter.Release,
          Skitter.ExitCodes
        ],
        "Runtime System (private)": ~r/Skitter.Runtime\..*/,
        "Remote Runtimes (private)": ~r/Skitter.Remote\..*/,
        "Runtime Modes (private)": ~r/Skitter.Mode\..*/
      ],
      filter_modules:
        if System.get_env("EX_DOC_PRIVATE") do
          fn _, _ -> true end
        else
          private = ~w(
            Skitter.Config
            Skitter.Telemetry
            Skitter.Runtime.
            Skitter.Remote.
            Skitter.Mode.
        )
          fn mod, _ -> not String.contains?(to_string(mod), private) end
        end
    ]
  end

  def before_closing_body_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.3/dist/mermaid.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        mermaid.initialize({ startOnLoad: false });
        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition, function (svgSource, bindListeners) {
            graphEl.innerHTML = svgSource;
            bindListeners && bindListeners(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end
end
