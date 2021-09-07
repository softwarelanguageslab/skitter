# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Release do
  @moduledoc false

  def step(rel) do
    rel
    |> override_options()
    |> add_skitter_deploy_script()
    |> add_skitter_runtime_config()
  end

  # We override the following options:
  #   - include_executables_for: we only provide unix deployment and management scripts, so only
  #     allow the release to be built for unix.
  #   - rel_templates_path: we provide our own vm.args and env.sh.eex inside the "rel" directory.
  defp override_options(r = %Mix.Release{options: opts}) do
    opts =
      opts
      |> put_new!(:include_executables_for, [:unix])
      |> put_new!(:rel_templates_path, Path.join([__DIR__, "release", "rel"]))

    %{r | options: opts}
  end

  # Add a script which is responsible for managing skitter runtimes and deploying it over a
  # cluster.
  defp add_skitter_deploy_script(r = %Mix.Release{steps: steps}) do
    %{r | steps: add_after_assemble(steps, &copy_skitter_deploy_script/1)}
  end

  defp copy_skitter_deploy_script(r = %Mix.Release{path: path}) do
    target = Path.join([path, "bin", "skitter"])

    Mix.Generator.copy_template(
      Path.join([__DIR__, "release", "skitter.sh.eex"]),
      target,
      [release: r, version: Application.spec(:skitter, :vsn)],
      force: true
    )

    File.chmod!(target, 0o744)

    r
  end

  # Include a script that configures the skitter runtime based on environment variables when a
  # release is started.
  defp add_skitter_runtime_config(r = %Mix.Release{config_providers: providers, steps: steps}) do
    config = {:system, "RELEASE_ROOT", "/releases/#{r.version}/skitter.exs"}
    steps = add_after_assemble(steps, &copy_skitter_runtime_config/1)
    %{r | config_providers: [{Config.Reader, config} | providers], steps: steps}
  end

  defp copy_skitter_runtime_config(r = %Mix.Release{version_path: path}) do
    File.cp!(Path.join([__DIR__, "release/skitter.exs"]), Path.join(path, "skitter.exs"))
    r
  end

  defp put_new!(kw, k, v) do
    if Keyword.has_key?(kw, k) do
      Mix.raise("Value found for Skitter defined configuration: #{k}")
    else
      Keyword.put(kw, k, v)
    end
  end

  defp add_after_assemble(steps, step) do
    idx = Enum.find_index(steps, &(&1 == :assemble))
    List.insert_at(steps, idx + 1, step)
  end
end
