# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc """
  Interface to Skitter's runtime system.
  """

  # --- #
  # API #
  # --- #

  def add_node(node) do
    GenServer.call(__MODULE__.Server, {:add_node, node}, :infinity)
  end

  def remove_node(node) do
    GenServer.cast(__MODULE__.Server, {:remove_node, node})
  end

  # ------ #
  # Server #
  # ------ #

  defmodule Server do
    @moduledoc false

    use GenServer
    require Logger

    def start_link(nodes) do
      GenServer.start_link(__MODULE__, nodes, name: __MODULE__)
    end

    @doc false
    def init(nodes) do
      rejected = connect(nodes)

      case rejected do
        [] -> {:ok, nodes}
        :not_distributed -> {:stop, :not_distributed}
        lst -> {:stop, {:invalid_nodes, lst}}
      end
    end

    # Nodes
    # -----

    def handle_call({:add_node, node}, _from, nodes) do
      case connect(node) do
        true -> {:reply, true, [node | nodes]}
        any -> {:reply, any, nodes}
      end
    end

    def handle_cast({:remove_node, node}, nodes) do
      Logger.info "Removing worker: #{node}"
      {:noreply, List.delete(nodes, node)}
    end

    defp connect([]), do: []

    defp connect(nodes) when is_list(nodes) do
      if Node.alive?() do
        nodes
        |> Enum.map(&connect/1)
        |> Enum.reject(&(&1 == true))
      else
        :not_distributed
      end
    end

    defp connect(node) when is_atom(node) do
      with true <- Node.connect(node),
           true <- Skitter.Runtime.Worker.verify_node(node),
           :ok <- Skitter.Runtime.Worker.register_master(node, Node.self()),
           {:ok, _p} <- Skitter.Runtime.NodeMonitorSupervisor.start_monitor(node) do
        Logger.info "Registered new worker: #{node}"
        true
      else
        :not_connected -> {:not_connected, node}
        :invalid -> {:no_skitter_worker, node}
        false -> {:not_connected, node}
        any -> {:error, any, node}
      end
    end
  end
end