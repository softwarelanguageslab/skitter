# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Strategy.Component do
  @moduledoc """
  Component strategy behaviour.

  This module defines and documents the various hooks a `Skitter.Strategy` for a component should
  implement, along with the functions it can use to access the runtime system.
  """
  alias Skitter.{Component, Strategy, Deployment, Worker, Port}

  @doc """
  Deploy a component over the cluster.

  This hook is called by the runtime system when a component has to be distributed over the
  cluster. Any data returned by this hook is made available to other hooks through the
  `deployment` field in `t:Skitter.Strategy.context/0`.

  ## Context

  When this hook is called, only the current strategy, component and arguments are available in
  the context.
  """
  @callback deploy(context :: Strategy.context()) :: Deployment.data()

  @doc """
  Accept data sent to the component and send it to a worker.

  This hook is called by the runtime system when data needs to be sent to a given component (i.e.
  when a predecessor of the component emits data). It receives the data to be sent along with the
  index of the port to which the data should be sent.

  The result of this hook is ignored. Instead, this hook should use `Skitter.Worker.send/3` to
  transfer the received data to a worker.

  ## Context

  All context data (component, strategy, deployment data and the invocation) is available when
  this hook is called.
  """
  @callback deliver(context :: Strategy.context(), data :: any(), port :: Port.index()) :: any()

  @doc """
  Handle a message received by a worker.

  This hook is called by the runtime when a worker process receives a message. It is called with
  the received message, the data of the worker that received the message and its tag.

  This callback should return a keyword list which may contain the following keys:

  - `state`: the new state of the worker that received the message. If this key is not present the
  state of the worker remains unchanged.

  - `emit`: data to emit. A keyword list of `{port, enum}` pairs. Each element in `enum` will be
  sent to each component connected to `port`. Note that `enum` may be a (potentially infinite)
  stream. This can be useful when creating strategies for source components which generate
  (infinite) streams of data.

  - `emit_invocation`: data to emit. A keyword list of `{port, enum}` pairs. Each element in
  `enum` should be a `{value, invocation}` tuple. This value will be sent to each component
  connect to `port` with the  provided invocation. `Skitter.Invocation.wrap/2` can be used to add
  new invocations to a list of emitted data.

  ## Context

  All context data (component, strategy, deployment data and the invocation) is available when
  this hook is called.

  When the received message was not sent by Skitter (i.e. when the worker process received a
  regular message), the invocation is set to `:external`. This can be used by e.g. sources to
  respond to external data.
  """
  @callback process(
              context :: Strategy.context(),
              message :: any(),
              state :: Worker.state(),
              tag :: Worker.tag()
            ) :: [
              state: Worker.state(),
              emit: Component.emit(),
              emit_invocation: Component.emit()
            ]

  def emit(context, enum) do
    # TODO:
    # - Hook this into runtime, emitter?
    # - Make several functions to publish, publish with invocation, etc
    # - Adjust strategies
    # - Adjust paper
    # - In this module because it needs to access the context
  end
end
