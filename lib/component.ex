# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component do
  @moduledoc """
  Component type definition and utilities.

  A component is a reusable data processing step that can be embedded inside of a workflow. It is
  defined as the combination of a set of callbacks, which implement the logic of the component,
  and some metadata, which define how the component is embedded inside a workflow and how it is
  distributed over the cluster at runtime.

  A skitter component is defined as an elixir module which implements the `Skitter.Component`
  behaviour. This behaviour defines various elixir callbacks which are used to track component
  information such as the defined callbacks. Instead of implementing a component as an elixir
  module, it is recommend to use `Skitter.DSL.Component.defcomponent/3`, which automatically
  generates the appropriate callbacks.

  This module defines the component type and behaviour along with utilities to handle components.

  ## Callbacks

  A component defines various _callbacks_: functions which implement the data processing logic of
  a component. These callbacks need to have the ability to modify state and emit data when they
  are called. Callbacks are implemented as elixir functions with a few properties:

  - Callbacks accept `t:state/0` and `t:config/0` as their first and second arguments.
  - Callbacks return a `t:result/0` struct, which wraps the result of the callback call along with
  the updated state and emitted data.

  Besides this, callbacks track additional information about whether they access or modify state
  and which data they emit. This information is stored inside the behaviour callbacks defined in
  this module.

  ## Examples

  Since components need to be defined in a module the example code shown in this module's
  documentation assumes the following module is defined:

  ```
  defmodule ComponentModule do
    @behaviour Skitter.Component
    alias Skitter.Component.Callback.{Info, Result}

    def _sk_component_info(:strategy), do: Strategy
    def _sk_component_info(:in_ports), do: [:input]
    def _sk_component_info(:out_ports), do: [:output]

    def _sk_component_initial_state, do: 42

    def _sk_callbacks, do: MapSet.new(example: 1)

    def _sk_callback_info(:example, 1) do
      %Info{read?: true, write?: false, emit?: true}
    end

    def example(state, config, arg) do
      result = state * config
      %Result{state: state, emit: [arg: arg], result: result}
    end
  end
  ```
  """

  use Skitter.Telemetry
  alias Skitter.{Strategy, Component.Callback.Info}

  # ----- #
  # Types #
  # ----- #

  @typedoc """
  A component is defined as a module.

  This module should implement the `Skitter.Component` behaviour.
  """
  @type t :: module()

  @typedoc """
  Input/output interface of Skitter components.

  The ports of a component determine its external interface. A port can be referred to by its
  name, which is stored as an atom.

  `in_port_to_index/2` and `out_port_to_index/2` can be used to convert a port name to a port
  index.
  """
  @type port_name() :: atom()

  @typedoc """
  Input/output interface of Skitter components.

  The ports of a component determine its external interface. A port can be referred to by its
  index in the in or out ports list of a component.

  `index_to_in_port/2` and `index_to_out_port/2` can be used to obtain the name of a port given
  its index.
  """
  @type port_index() :: non_neg_integer()

  @typedoc """
  Arguments passed to a callback when it is called.

  The arguments are wrapped in a list.
  """
  @type args :: [any()]

  @typedoc """
  State passed to the callback when it is called.
  """
  @type state :: any()

  @typedoc """
  Configuration passed to the callback when it is called.

  The configuration represents the immutable state of a component. It is explicitly separated from
  the mutable `t:state/0` to enable strategies to explicitly differentiate between handling
  mutable and immutable data.
  """
  @type config :: any()

  @typedoc """
  Output emitted by a callback.

  Emitted data is returned as a keyword list where the output for each out port is specified. When
  no data is emitted on a port, the port should be omitted from the list. The data emitted by a
  callback for a port should be wrapped in an `t:Enumerable.t/0`. Each element in this enumerable
  will be sent to downstream components separately.
  """
  @type emit :: [{port_name(), Enumerable.t()}]

  @typedoc """
  Values returned by a callback when it is called.

  The following information is stored:

  - `:result`: The actual result of the callback, i.e. the final value returned in its body.
  - `:state`: The (possibly modified) state after calling the callback.
  - `:emit`: The list of output emitted by the callback.
  """
  @type result :: %__MODULE__.Callback.Result{
          result: any(),
          state: state(),
          emit: emit()
        }

  @typedoc """
  Additional callback information. Can be retrieved with `info/2`.

  The following information is stored:

  - `:read?`: Boolean which indicates if the callback reads the component state.
  - `:write?`: Boolean which indicates if the callback updates the component state.
  - `:emit`: Boolean which indicates if the callback emits data.
  """
  @type info :: %__MODULE__.Callback.Info{
          read?: boolean(),
          write?: boolean(),
          emit?: boolean()
        }

  # Struct Definitions
  # ------------------

  defmodule Callback do
    @moduledoc false

    defmodule Result do
      @moduledoc false
      defstruct [:state, :emit, :result]
    end

    defmodule Info do
      @moduledoc false
      defstruct read?: false, write?: false, emit?: false
    end
  end

  # --------- #
  # Behaviour #
  # --------- #

  @doc """
  Returns the meta-information of the component.

  The following information is stored:

  - `:in_ports`: A list of port names which represents in ports through which the component
  receives incoming data.

  - `:out_ports`: A list of out ports names which represents the out ports the component can use
  to emit data.

  - `:strategy`: The `Skitter.Strategy` of the component. `nil` may be provided instead, in which
  case a strategy must be provided when the component is embedded in a workflow.
  """
  @callback _sk_component_info(:in_ports) :: [port_name()]
  @callback _sk_component_info(:out_ports) :: [port_name()]
  @callback _sk_component_info(:strategy) :: Strategy.t() | nil

  @doc """
  Return the names and arities of all the callbacks defined in this module.
  """
  @callback _sk_callbacks() :: MapSet.t({atom(), arity()})

  @doc """
  Return the callback information of callback `name`, `arity`.
  """
  @callback _sk_callback_info(name :: atom(), arity()) :: info()

  @doc """
  Returns the initial state of the component.

  This function returns an initial state for the component. The state of a component is component
  specific: Skitter places no constraints on this state.
  """
  @callback _sk_component_initial_state() :: any()

  # --------- #
  # Utilities #
  # --------- #

  # Component
  # ---------

  @doc """
  Check if a given value refers to a component module.

  ## Examples

      iex> component?(5)
      false
      iex> component?(String)
      false
      iex> component?(ComponentModule)
      true
  """
  @spec component?(any()) :: boolean()
  def component?(atom) when is_atom(atom) do
    :erlang.function_exported(atom, :_sk_component_info, 1)
  end

  def component?(_), do: false

  @doc """
  Create the initial state for `component`.

  ## Examples

      iex> initial_state(ComponentModule)
      42
  """
  @spec initial_state(t()) :: state()
  def initial_state(component), do: component._sk_component_initial_state()

  @doc """
  Obtain the strategy of `component`.

  ## Examples

      iex> strategy(ComponentModule)
      Strategy
  """
  @spec strategy(t()) :: Strategy.t() | nil
  def strategy(component), do: component._sk_component_info(:strategy)

  @doc """
  Obtain the arity of `component`.

  The arity is defined as the amount of in ports the component defines.

  ## Examples

      iex> arity(ComponentModule)
      1
  """
  @spec arity(t()) :: arity()
  def arity(component), do: component |> in_ports() |> length()

  @doc """
  Obtain the list of in ports of `component`.

  ## Examples

      iex> in_ports(ComponentModule)
      [:input]
  """
  @spec in_ports(t()) :: [port_name()]
  def in_ports(component), do: component._sk_component_info(:in_ports)

  @doc """
  Obtain the list of out ports of `component`.

  ## Examples

      iex> out_ports(ComponentModule)
      [:output]
  """
  @spec out_ports(t()) :: [port_name()]
  def out_ports(component), do: component._sk_component_info(:out_ports)

  @doc """
  Get the index of an in port.

  ## Examples

      iex> in_port_to_index(ComponentModule, :input)
      0
      iex> in_port_to_index(ComponentModule, :other)
      nil
  """
  @spec in_port_to_index(t(), port_name()) :: port_index() | nil
  def in_port_to_index(component, port) do
    component |> in_ports() |> Enum.find_index(&(&1 == port))
  end

  @doc """
  Get the index of an out port.

  ## Examples

      iex> out_port_to_index(ComponentModule, :output)
      0
      iex> out_port_to_index(ComponentModule, :other)
      nil
  """
  @spec out_port_to_index(t(), port_name()) :: port_index() | nil
  def out_port_to_index(component, port) do
    component |> out_ports() |> Enum.find_index(&(&1 == port))
  end

  @doc """
  Convert an index of an in port to a port name.

  ## Examples

      iex> index_to_in_port(ComponentModule, 0)
      :input
      iex> index_to_in_port(ComponentModule, 1)
      nil
  """
  @spec index_to_in_port(t(), port_index()) :: port_name() | nil
  def index_to_in_port(component, idx), do: component |> in_ports() |> Enum.at(idx)

  @doc """
  Convert an index of an out port to a port name.

  ## Examples

      iex> index_to_out_port(ComponentModule, 0)
      :output
      iex> index_to_out_port(ComponentModule, 1)
      nil
  """
  @spec index_to_out_port(t(), port_index()) :: port_name() | nil
  def index_to_out_port(component, idx), do: component |> out_ports() |> Enum.at(idx)

  @doc """
  Check if a component is a source.

  A component is a source if it does not have any in ports.

  ## Examples

      iex> source?(ComponentModule)
      false
  """
  @spec source?(t()) :: boolean()
  def source?(component), do: component |> in_ports() |> length() == 0

  @doc """
  Check if a component is a sink.

  A component is a sink if it does not have any out ports.

  ## Examples

      iex> sink?(ComponentModule)
      false
  """
  @spec sink?(t()) :: boolean()
  def sink?(component), do: component |> out_ports() |> length() == 0

  # Callbacks
  # ---------

  @doc """
  Check if `component` defines a callback with `name` and `arity`.

  ## Examples

    iex> callback_exists?(ComponentModule, :example, 1)
    true

    iex> callback_exists?(ComponentModule, :example, 2)
    false
  """
  @spec callback_exists?(t(), atom(), arity()) :: boolean()
  def callback_exists?(component, name, arity) do
    {name, arity} in callbacks(component)
  end

  @doc """
  Obtain the set of all callbacks defined in `component`.

  ## Examples

  iex> callbacks(ComponentModule)
  #MapSet<[example: 1]>

  """
  @spec callbacks(t()) :: [{atom(), arity()}]
  def callbacks(component), do: component._sk_callbacks()

  @doc """
  Obtain the callback information for callback `name`, `arity` in `component`.

  ## Examples

      iex> callback_info(ComponentModule, :example, 1)
      %Info{read?: true, write?: false, emit?: true}

  """
  @spec callback_info(t(), atom(), arity()) :: info()
  def callback_info(component, name, arity), do: component._sk_callback_info(name, arity)

  @doc """
  Call callback `callback_name` with `state`, `config` and `arguments`.

  ## Examples

      iex> call(ComponentModule, :example, 10, 2, [:foo])
      %Skitter.Component.Callback.Result{state: 10, result: 20, emit: [arg: :foo]}
  """
  @spec call(t(), atom(), state(), config(), args()) :: result()
  def call(component, name, state, config, args) do
    Telemetry.wrap [:component, :call], %{
      pid: self(),
      component: component,
      name: name,
      state: state,
      config: config,
      args: args
    } do
      apply(component, name, [state, config | args])
    end
  end

  @doc """
  Call callback `callback_name` with an empty state, `config` and `arguments`.

  This function calls `Skitter.Component.call/5` with the state created by `initial_state/1`.

  ## Examples

      iex> call(ComponentModule, :example, 2, [:foo])
      %Skitter.Component.Callback.Result{state: 42, result: 84, emit: [arg: :foo]}
  """
  @spec call(t(), atom(), config(), args()) :: result()
  def call(component, callback_name, config, args) do
    call(component, callback_name, initial_state(component), config, args)
  end

  @doc """
  Call callback `callback_name` with an empty state and config and `arguments`.

  This function calls `Skitter.Component.call/5` with the state created by `initial_state/1`.
  `nil` is used as the value for `config`.
  """
  @spec call(t(), atom(), args()) :: result()
  def call(component, callback_name, args) do
    call(component, callback_name, initial_state(component), nil, args)
  end

  @doc """
  Call callback `callback_name` with an empty state and config and arguments.

  This function calls `Skitter.Component.call/5` with the state created by `initial_state/1`.
  `nil` is used as the value for `config`, no arguments are passed.
  """
  @spec call(t(), atom()) :: result()
  def call(component, callback_name) do
    call(component, callback_name, initial_state(component), nil, [])
  end

  @doc """
  Call `callback_name` defined by `component` if it exists.

  Calls the callback with the given name with `state`, `config` and `args` if
  `{name, length(args)}` exists. If the callback does not exist, a  result with the
  `initial_state/1` of the component, an empty emit list and `nil` as result is returned.

  ## Examples

      iex> call_if_exists(ComponentModule, :example, 10, 2, [:foo])
      %Skitter.Component.Callback.Result{state: 10, result: 20, emit: [arg: :foo]}
      iex> call_if_exists(ComponentModule, :example, 10, 2, [:foo, :bar])
      %Skitter.Component.Callback.Result{state: 42, result: nil, emit: []}
  """
  @spec call_if_exists(t(), atom(), state(), config(), args()) :: result()
  def call_if_exists(component, callback_name, state, config, args) do
    if callback_exists?(component, callback_name, length(args)) do
      call(component, callback_name, state, config, args)
    else
      %Callback.Result{
        state: initial_state(component),
        result: nil,
        emit: []
      }
    end
  end

  @doc """
  Call `callback_name` defined by `component` if it exists.

  Like `call_if_exists/5`, but `state` is replaced by the initial state of the component.
  """
  @spec call_if_exists(t(), atom(), config(), args()) :: result()
  def call_if_exists(component, callback_name, config, args) do
    call_if_exists(component, callback_name, initial_state(component), config, args)
  end

  @doc """
  Call `callback_name` defined by `component` if it exists.

  Like `call_if_exists/5`, but `state` is replaced by the initial state of the component and
  `config` is `nil`.
  """
  @spec call_if_exists(t(), atom(), args()) :: result()
  def call_if_exists(component, callback_name, args) do
    call_if_exists(component, callback_name, initial_state(component), nil, args)
  end

  @doc """
  Call `callback_name` defined by `component` if it exists.

  Like `call_if_exists/5`, but `state` is replaced by the initial state of the component, `config`
  is `nil` and `args` is the empty list.
  """
  @spec call_if_exists(t(), atom()) :: result()
  def call_if_exists(component, callback_name) do
    call_if_exists(component, callback_name, initial_state(component), nil, [])
  end
end
