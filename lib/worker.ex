# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker do
  @moduledoc """
  Data processor which can perform work for a component.
  """
  alias Skitter.{Context, Component, Invocation}

  # ----- #
  # Types #
  # ----- #

  @typedoc """
  Reference to an existing worker.
  """
  @opaque ref :: pid()

  @typedoc """
  Worker identification tag.
  """
  @type tag :: atom()

  @typedoc """
  Worker lifetime.

  A worker can remain alive through the duration of a deployment or an invocation. The scheduler
  may use this information to determine how to schedule a worker.
  """
  @type lifetime :: :deployment | :invocation

  @typedoc """
  Placement constraints.

  Workers may need to put some constraints on the node on which they are spawned. These
  constraints are represented by this type. The following constraints are currently supported:

  - `:with` place the worker on the same location as the given worker.
  - `:avoid` try to place the worker on a different node as the given worker.
  - `:on` place the worker on the specified location.
  """
  @type constraints :: [with: ref(), avoid: ref(), on: node()]

  # --- #
  # API #
  # --- #

  @ps_key :skitter_worker_spawner_mod

  @doc false
  def set_create_module(mod), do: :persistent_term.put(@ps_key, mod)

  @doc """
  Create a new worker.
  """
  @spec create(
          Component.t(),
          Context.t(),
          any() | (() -> any()),
          tag(),
          lifetime(),
          constraints()
        ) :: ref()
  def create(component, context, state, tag, lifetime, constraints \\ []) do
    mod = :persistent_term.get(@ps_key)
    mod.create(component, context, state, tag, lifetime, constraints)
  end

  @doc """
  Send a message to a worker reference.
  """
  @spec send(ref(), any(), Invocation.ref()) :: :ok
  def send(ref, message, invocation), do: GenServer.cast(ref, {:msg, message, invocation})

  @doc """
  Stop the referenced worker.
  """
  @spec stop(ref()) :: :ok
  def stop(ref), do: GenServer.cast(ref, :stop)
end
