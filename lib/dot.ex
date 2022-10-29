# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Dot do
  @moduledoc """
  Export skitter workflows as [graphviz](https://graphviz.org/) dot graphs.

  The main function in this module is the `to_dot/1` function, which accepts a skitter workflow
  and returns its dot representation as a string. End users may prefer the `print_dot/1` function,
  which immediately prints the returned string. If dot is installed on the system, the `export/3`
  function can be used to export the generated graph in a variety of formats.
  """
  alias Skitter.{Operation, Workflow}
  alias Skitter.Workflow.Node.Operation, as: O
  alias Skitter.Workflow.Node.Workflow, as: W

  @doc """
  Return the dot representation of a workflow as a string.
  """
  @spec to_dot(Workflow.t()) :: String.t()
  def to_dot(w = %Workflow{}), do: container(workflow: w)

  @doc """
  Renders the generated dot graph, requires dot to be installed on the system.

  This function exports a given workflow to the dot language (using `to_dot/1`), after which it
  calls `dot` on the generated dot representation. When `dot` returns successfully, `{:ok,
  string}` is returned, where `string` is the output generated by `dot`.

  A `format` should be specified. This format is passed to `dot` through the use of its `-T`
  option. For a list of the options supported on your system, see `man dot`.

  An optional list of options may be passed to further configure the use of `dot`. The following
  options are supported:
  - `dot_exe`: the path to the dot executable, by default, this function assumes dot is present in
  your `$PATH`.
  - `extra`: a list of extra arguments to pass to the dot executable.

  ## Examples

  Save `workflow` as a svg file:
  ```
  render(workflow, "svg")
  ```
  """
  @spec render(Workflow.t(), String.t(), dot_exe: String.t(), extra: [String.t()]) ::
          {:ok, binary()} | {:error, String.t()}
  def render(w = %Workflow{}, format, opts \\ []) do
    dotfile = System.tmp_dir!() |> Path.join("skitter_export.gv")
    File.write!(dotfile, to_dot(w))

    dot_exe = Keyword.get(opts, :dot_exe, "dot")
    extra = Keyword.get(opts, :extra, [])

    res =
      case System.cmd(dot_exe, ["-T#{format}"] ++ extra ++ [dotfile]) do
        {out, 0} -> {:ok, out}
        {out, 1} -> {:error, out}
      end

    File.rm!(dotfile)
    res
  end

  @doc """
  Renders the generated dot graph and save it to `path`.

  Renders the provided workflow (with `render/3`) and store the output to `path`. `format` and
  `opts` are passed to `render/3`.
  """
  @spec render_to_file(Workflow.t(), String.t(), String.t(),
          dot_exe: String.t(),
          extra: [String.t()]
        ) :: :ok | {:error, String.t()}
  def render_to_file(w = %Workflow{}, format \\ "pdf", path \\ "dot.pdf", opts \\ []) do
    opts = Keyword.merge(opts, [extra: ["-o", path]], fn _, l, r -> l ++ r end)

    case render(w, format, opts) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  # Templates & Helpers
  # -------------------

  require EEx

  # Load all templates
  __DIR__
  |> Path.join("dot/*.eex")
  |> Path.wildcard()
  |> Enum.map(fn file ->
    fname = file |> Path.basename(".eex") |> String.to_atom()
    EEx.function_from_file(:defp, fname, file, [:assigns], trim: true)
  end)

  # Path is used to avoid name conflicts in nested workflows
  defp expand_path("", id), do: Atom.to_string(id)
  defp expand_path(path, id), do: "#{path}_#{Atom.to_string(id)}"

  # Ports are prefixed with path and their "type" (in or out)
  defp port_path("", prefix, port), do: ~s/"#{prefix}_#{port}"/
  defp port_path(path, prefix, port), do: ~s/"#{path}_#{prefix}_#{port}"/

  # Pattern match to treat workflows and operations differently
  defp workflow_node(id, o = %O{}, path) do
    operation(id: id, operation: o.operation, strategy: o.strategy, path: path)
  end

  defp workflow_node(id, w = %W{}, path) do
    workflow_nested(id: id, workflow: w.workflow, path: expand_path(path, id))
  end

  defp destination({name, port}, path, workflow) do
    case workflow.nodes[name] do
      %O{} -> ~s/"#{expand_path(path, name)}":in_#{port}/
      %W{} -> path |> expand_path(name) |> port_path("in", port)
    end
  end

  defp destination(port, path, _), do: port_path(path, "out", port)

  defp source(name, %O{}, port, path), do: ~s/"#{expand_path(path, name)}":out_#{port}/
  defp source(name, %W{}, port, path), do: path |> expand_path(name) |> port_path("out", port)
end
