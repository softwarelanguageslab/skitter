# Copyright 2018 - 2023, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule SkitterNew.MixProject do
  use Mix.Project

  @github_url "https://github.com/mathsaey/skitter/"
  @home_url "https://soft.vub.ac.be/~mathsaey/skitter/"

  def project do
    [
      app: :skitter_new,
      elixir: "~> 1.15",
      version: "0.7.0",
      source_url: @github_url,
      homepage_url: @home_url,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  defp description do
    """
    Skitter project generator.

    Provides a `mix skitter.new` task to set up a Skitter project.
    """
  end

  defp package do
    [
      licenses:  ["MPL-2.0"],
      links: %{github: @github_url, homepage: @home_url}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
    ]
  end

  def application do
    [
      extra_applications: [:eex]
    ]
  end

  defp docs do
    [
      main: "Mix.Tasks.Skitter.New",
      api_reference: false
    ]
  end
end
