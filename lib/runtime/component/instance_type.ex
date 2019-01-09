# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.InstanceType do
  @moduledoc false

  alias Skitter.Runtime.Component

  @doc """
  Return a module supervisor which can supervise the current instance type.
  """
  @callback supervisor() :: module()

  @doc """
  Load the runtime version of the component instance.

  The `reference()` argument is a unique reference which identifies the
  instance to be loaded.  The `component` and `init_arguments` which are passed
  to this callback will be passed to `Skitter.Component.init/2`.

  This callback should initialize the component and provide some reference to
  the component which can be used by `react/2`
  """
  @callback load(reference(), Skitter.Component.t(), any()) :: any()

  @doc """
  Ask the component instance to react to incoming data.

  The first argument should be the return value of `load/2`, the second value
  should be the list of arguments which will be passed to
  `Skitter.Component.react/2`.

  This functions returns a tuple containing `:ok`, the pid of the process
  which reacts, and a unique reference for this invocation of react.
  When the instance has finished reacting, the process which made the react
  request will receive the following tuple: `{:react_finished, ref, spits}`,
  where ref is the reference that was returned from the function, while spits
  contains the spits produced by the invocation of react.
  """
  @callback react(any(), [any(), ...]) :: {:ok, pid(), reference()}

  def select(comp) do
    if Skitter.Component.state_change?(comp) do
      Component.PermanentInstance
    else
      Component.TransientInstance
    end
  end
end