# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Strategy.Component do
  @moduledoc """
  Component strategy behaviour.

  This module defines and documents the various hooks a `Skitter.Strategy` for a component should
  implement.
  """
  alias Skitter.{Component, Strategy, Port, Deployment, Worker}

  @doc """
  Deploy a component over the cluster.

  This hook is called by the runtime system when a component has to be distributed over the
  cluster. It receives the arguments passed to `t:Skitter.Workflow.component/0` as its only
  argument. Any data returned by this hook is made available to other hooks through the
  `deployment` field in `t:Skitter.Strategy.context/0`.

  ## Context

  When this hook is called, only the current strategy and component are available in the context.
  """
  @callback deploy(context :: Strategy.context(), args :: any()) :: Deployment.data()

  @doc """
  Send a message to the component.

  This hook is called by the runtime system when data needs to be sent to a given component (e.g.
  when a predecessor of the component publishes data). It receives the data to be sent along with
  the port to which the data should be sent. The result of this hook is ignored.

  ## Context

  All context data (component, strategy, deployment data and the invocation) is available when
  this hook is called.
  """
  @callback send(context :: Strategy.context(), data :: any(), port :: Port.t() | nil) :: any()

  @doc """
  Handle a message received by the component.

  This hook is called by the runtime when a worker process receives a message. It is called with
  the received message, the data of the worker that received the message and its tag.

  This callback should return a keyword list which may contain the following keys:

  - `state`: the new state of the worker that received the message. If this key is not present the
  state of the worker remains unchanged.

  - `publish`: data to be published. A keyword list of `{port, lst}` pairs. Each element in `lst`
  will be sent to each component connected to `port`.

  ## Context

  All context data (component, strategy, deployment data and the invocation) is available when
  this hook is called.

  When the received message was not sent by Skitter (i.e. when the worker process received a
  regular message), the invocation is set to `:external`. This can be used by e.g. sources to
  respond to external data.
  """
  @callback receive(
              context :: Strategy.context(),
              message :: any(),
              state :: Worker.state(),
              tag :: Worker.tag()
            ) :: [state: Worker.state(), publish: Component.publish()]
end
