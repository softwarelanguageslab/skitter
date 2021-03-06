# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Worker.RegistryManager do
  @moduledoc false
  use GenServer

  alias Skitter.Remote
  alias Skitter.Remote.{Registry, Tags}
  alias Skitter.Mode.Master.WorkerConnection

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def master_up(remote), do: GenServer.cast(__MODULE__, {:master_up, remote})
  def master_down(remote), do: GenServer.cast(__MODULE__, {:master_down, remote})

  @impl true
  def init([]) do
    Registry.start_link()
    Tags.start_link()

    Registry.add(Node.self(), :worker)
    Tags.add(Node.self(), Tags.local())

    {:ok, :no_master}
  end

  @impl true
  def handle_cast({:master_up, remote}, :no_master) do
    :ok = WorkerConnection.subscribe_up(remote)
    :ok = WorkerConnection.subscribe_down(remote)

    Registry.add(remote, :master)

    remote
    |> Remote.on(Tags, :of_all_workers, [])
    |> Enum.each(fn {node, tags} ->
      Registry.add(node, :worker)
      Tags.add(node, tags)
    end)

    {:noreply, remote}
  end

  def handle_cast({:master_down, remote}, _) do
    :ok = WorkerConnection.unsubscribe_up(remote)
    :ok = WorkerConnection.unsubscribe_down(remote)

    Registry.remove_all()
    Registry.add(Node.self(), :worker)

    Tags.remove_all()
    Tags.add(Node.self(), Tags.local())

    {:noreply, :no_master}
  end

  @impl true
  def handle_info({:worker_up, node, tags}, state) do
    Registry.add(node, :worker)
    Tags.add(node, tags)
    {:noreply, state}
  end

  @impl true
  def handle_info({:worker_down, node}, state) do
    Registry.remove(node)
    Tags.remove(node)
    {:noreply, state}
  end
end
