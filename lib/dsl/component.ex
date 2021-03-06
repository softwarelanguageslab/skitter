# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Component do
  @moduledoc """
  Callback and Component definition DSL.

  This module offers macros to define component modules and callbacks. Please refer to the
  documentation of `defcomponent/3`.
  """
  alias Skitter.DSL.AST
  alias Skitter.{Component.Callback.Info, DefinitionError}

  # --------- #
  # Component #
  # --------- #

  @doc """
  Defines the initial state of a component.

  This macro is used to define the initial state of a component. This state is passed to every
  called callback when no state is provided by the component's strategy. When this macro is not
  used, the initial state of a component is `nil`.

  Internally, this macro generates a definition of
  `c:Skitter.Component._sk_component_initial_state/0`.

  ## Examples

  ```
  defcomponent NoStateExample do
    defcb return_state, do: state()
  end

  defcomponent StateExample do
    state 0
    defcb return_state, do: state()
  end
  ```

      iex> Component.initial_state(NoStateExample)
      nil

      iex> Component.initial_state(StateExample)
      0

      iex> Component.call(NoStateExample, :return_state, []).state
      nil

      iex> Component.call(StateExample, :return_state, []).state
      0

      iex> Component.call(NoStateExample, :return_state, :some_state, nil, []).state
      :some_state

      iex> Component.call(StateExample, :return_state, :some_state, nil, []).state
      :some_state


  """
  defmacro state(initial_state) do
    quote do
      @impl true
      def _sk_component_initial_state, do: unquote(initial_state)
    end
  end

  @doc """
  Creates an initial struct-based state for a component.

  In Elixir, it is common to use a struct to store structured information. Therefore, when a
  component manages a complex state, it often defines a struct and uses this struct as the initial
  state of the component. Afterwards, the state of the component is updated when it reacts to
  incoming data:

  ```
  defcomponent Average, in: value, out: current do
    defstruct [total: 0, count: 0]
    state %__MODULE__{}

    defcb react(val) do
      state <~ %{state() | count: state().count + 1}
      state <~ %{state() | total: state().total + val}
      state().total / state().count ~> current
    end
  end
  ```

  In order to streamline the use of this pattern, this macro defines a struct and uses this struct
  as the initial state of the component. Moreover, the `sigil_f/2` and `~>/2` macros are designed
  to be used with structs, enabling them to read the state and update it:

  ```
  defcomponent Average, in: value, out: current do
    state_struct total: 0, count: 0

    defcb react(val) do
      count <~ ~f{count} + 1
      total <~ ~f{total} + val
      ~f{total} / ~f{count} ~> current
    end
  end
  ```

  The second example generates the code shown in the first example.

  ## Examples

      iex> Component.initial_state(Average)
      %Average{total: 0, count: 0}

  """
  defmacro state_struct(fields) do
    quote do
      defstruct unquote(fields)
      state %__MODULE__{}
    end
  end

  @doc """
  Define a component module.

  This macro is used to define a component module. Using this macro, a component can be defined
  similar to a normal module. The macro will enable the use of `defcb/2` and provides
  implementations for `c:Skitter.Component._sk_component_info/1`,
  `c:Skitter.Component._sk_component_initial_state/0`, `c:Skitter.Component._sk_callbacks/0`
  and `c:Skitter.Component._sk_callback_info/2`.

  ## Component strategy and ports

  The component Strategy and its in -and out ports can be defined in the header of the component
  declaration as follows:

      iex> defcomponent SignatureExample, in: [a, b, c], out: [y, z], strategy: SomeStrategy do
      ...> end
      iex> Component.strategy(SignatureExample)
      SomeStrategy
      iex> Component.in_ports(SignatureExample)
      [:a, :b, :c]
      iex> Component.out_ports(SignatureExample)
      [:y, :z]

  If a component has no `in`, or `out` ports, they can be omitted from the component's header.
  Furthermore, if the component only has a single `in` or `out` port, the list notation can be
  omitted:

      iex> defcomponent PortExample, in: a do
      ...> end
      iex> Component.in_ports(PortExample)
      [:a]
      iex> Component.out_ports(PortExample)
      []

  The strategy may be omitted. In this case, a strategy _must_ be provided when the defined
  component is embedded inside a workflow. If this is not done, an error will be raised when the
  workflow is deployed.

  ## Examples

  ```
  defcomponent Average, in: value, out: current do
    state_struct total: 0, count: 0

    defcb react(value) do
      total <~ ~f{total} + value
      count <~ ~f{count} + 1

      ~f{total} / ~f{count} ~> current
    end
  end
  ```

      iex> Component.in_ports(Average)
      [:value]
      iex> Component.out_ports(Average)
      [:current]


      iex> Component.strategy(Average)
      nil

      iex> Component.call(Average, :react, [10])
      %Result{result: nil, emit: [current: [10.0]], state: %Average{count: 1, total: 10}}

      iex> Component.call(Average, :react, %Average{count: 1, total: 10}, nil, [10])
      %Result{result: nil, emit: [current: [10.0]], state: %Average{count: 2, total: 20}}

  ## Documentation

  When writing documentation for a component, `@componentdoc` can be used instead of the usual
  `@moduledoc`. When this is done, this macro will automatically add additional information about
  the component to the generated documentation.
  """
  defmacro defcomponent(name, opts \\ [], do: body) do
    in_ = opts |> Keyword.get(:in, []) |> AST.names_to_atoms()
    out = opts |> Keyword.get(:out, []) |> AST.names_to_atoms()
    strategy = opts |> Keyword.get(:strategy) |> read_strategy(__CALLER__)

    quote do
      defmodule unquote(name) do
        @behaviour Skitter.Component
        import unquote(__MODULE__), only: [state: 1, state_struct: 1, defcb: 2]

        @before_compile {unquote(__MODULE__), :generate_callbacks}
        @before_compile {unquote(__MODULE__), :generate_moduledoc}
        Module.register_attribute(__MODULE__, :_sk_callbacks, accumulate: true)

        @_sk_strategy unquote(strategy)
        @_sk_in_ports unquote(in_)
        @_sk_out_ports unquote(out)

        @impl true
        def _sk_component_initial_state, do: nil
        defoverridable _sk_component_initial_state: 0

        unquote(body)
      end
    end
  end

  defp read_strategy(mod, env) do
    case Macro.expand(mod, env) do
      mod when is_atom(mod) -> mod
      any -> DefinitionError.inject("Invalid strategy: `#{inspect(any)}`", env)
    end
  end

  @doc false
  # generate component behaviour callbacks
  defmacro generate_callbacks(env) do
    names = env.module |> _info_before_compile() |> Map.keys()
    metadata = env.module |> _info_before_compile() |> Macro.escape()

    state =
      case Module.get_attribute(env.module, :_sk_initial_state) do
        :_sk_gen_struct -> quote(do: %__MODULE__{}) |> Macro.escape()
        any -> any
      end

    quote bind_quoted: [names: names, metadata: metadata, state: state] do
      @impl true
      def _sk_component_info(:strategy), do: @_sk_strategy
      def _sk_component_info(:in_ports), do: @_sk_in_ports
      def _sk_component_info(:out_ports), do: @_sk_out_ports

      @impl true
      def _sk_callbacks, do: unquote(names |> MapSet.new() |> Macro.escape())

      # Prevent a warning if no callbacks are defined
      @impl true
      def _sk_callback_info(nil, 0), do: %Skitter.Component.Callback.Info{}

      for {{name, arity}, info} <- metadata do
        def _sk_callback_info(unquote(name), unquote(arity)), do: unquote(Macro.escape(info))
      end
    end
  end

  defmacro generate_moduledoc(env) do
    mod = env.module
    in_ports = Module.get_attribute(mod, :_sk_in_ports) |> Enum.join(", ") |> wrap_value()
    out_ports = Module.get_attribute(mod, :_sk_out_ports) |> Enum.join(", ") |> wrap_value()
    strategy = Module.get_attribute(mod, :_sk_strategy) |> wrap_value()

    if Module.has_attribute?(mod, :componentdoc) do
      quote do
        @moduledoc """
        #{@componentdoc}

        ## Component Properties

        * in ports: #{unquote(in_ports)}
        * out ports: #{unquote(out_ports)}
        * default strategy: #{unquote(strategy)}
        """
      end
    end
  end

  defp wrap_value(""), do: "none"
  defp wrap_value(nil), do: "none"
  defp wrap_value(str) when is_binary(str), do: "`#{str}`"

  defp wrap_value(mod) when is_atom(mod) do
    mod |> Module.split() |> Enum.join(".") |> wrap_value()
  end

  # --------- #
  # Callbacks #
  # --------- #

  # Private / Hidden Helpers
  # ------------------------

  @doc false
  # Gets the callback info before generate_callback_info/1 is called.
  def _info_before_compile(module) do
    module
    |> Module.get_attribute(:_sk_callbacks)
    |> Enum.reduce(%{}, fn {{name, arity}, info}, map ->
      Map.update(map, {name, arity}, info, fn s = %Info{} ->
        %{
          s
          | read?: s.read? or info.read?,
            write?: s.write? or info.write?,
            emit?: s.emit? or info.emit?
        }
      end)
    end)
  end

  # Extract calls to a certain operator from the AST
  defp extract(body, verify) do
    body
    |> Macro.prewalk(MapSet.new(), fn
      node, acc -> if el = verify.(node), do: {node, MapSet.put(acc, el)}, else: {node, acc}
    end)
    |> elem(1)
    |> Enum.to_list()
  end

  defp extract_not_empty?(body, verify) do
    body |> extract(verify) |> Enum.empty?() |> Kernel.not()
  end

  # Config
  # ------

  @doc false
  def config_var, do: quote(do: var!(config, unquote(__MODULE__)))

  @doc """
  Obtain the component configuration.

  This macro reads the current value of the configuration passed to the component callback when
  it was called. It should only be used inside the body of `defcb/2`.

  ## Examples

  ```
  defcomponent ConfigExample do
    defcb read(), do: config()
  end
  ```

      iex> Component.call(ConfigExample, :read, []).result
      nil

      iex> Component.call(ConfigExample, :read, :config, []).result
      :config

      iex> Component.call(ConfigExample, :read, :state, :config, []).result
      :config
  """
  defmacro config, do: quote(do: unquote(config_var()))

  # State
  # -----

  @doc false
  def state_var, do: quote(do: var!(state, unquote(__MODULE__)))

  @doc """
  Obtain the current state.

  This macro reads the current value of the state passed to the component callback when it was
  called. It should only be used inside the body of `defcb/2`.

  ## Examples

  ```
  defcomponent ReadExample do
    state 0
    defcb read(), do: state()
  end
  ```

      iex> Component.call(ReadExample, :read, []).result
      0

      iex> Component.call(ReadExample, :read, :state, nil, []).result
      :state

      iex> Component.call(ReadExample, :read, :state, nil, []).result
      :state
  """
  defmacro state, do: quote(do: unquote(state_var()))

  @doc """
  Read the current value of a field stored in state.

  This macro expects that the current component state is a struct (i.e. it expects a component
  that uses `state_struct/1`), and reads the current value of `field` from the struct.

  This macro should only be used inside the body of `defcb/2`.

  ## Examples

  ```
  defcomponent FieldReadExample do
    state_struct field: nil
    defcb read(), do: ~f{field}
  end
  ```

      iex> Component.call(FieldReadExample, :read, %FieldReadExample{field: 5}, nil, []).result
      5

      iex> Component.call(FieldReadExample, :read, %FieldReadExample{field: :foo}, nil, []).result
      :foo
  """
  defmacro sigil_f({:<<>>, _, [str]}, _) do
    field = str |> String.to_existing_atom()
    quote(do: Map.fetch!(unquote(state_var()), unquote(field)))
  end

  @doc """
  Updates the current state.

  This macro should only be used inside the body of `defcb/2`. It updates the current value of the
  component state to the provided value.

  This macro can be used  in two ways: it can be used to update the component state or a field of
  the component state. The latter option can only be used if the state of the component is a
  struct (i.e. if the intial state has been defined using `state_struct/1`). The former options
  modifies the component state as a whole, the second option only modifies the value of the
  provided field stored in the component state.

  ## Examples

  ```
  defcomponent WriteExample do
    defcb write(), do: state <~ :foo
  end
  ```
      iex> Component.call(WriteExample, :write, nil, nil, []).state
      :foo

  ```
  defcomponent FieldWriteExample do
    state_struct [:field]
    defcb write(), do: field <~ :bar
  end
  ```
      iex> Component.call(FieldWriteExample, :write, %FieldWriteExample{field: :foo}, nil, []).state.field
      :bar

  ```
  defcomponent WrongFieldWriteExample do
    fields [:field]
    defcb write(), do: doesnotexist <~ :bar
  end
  ```
      iex> Component.call(WrongFieldWriteExample, :write, %WrongFieldWriteExample{field: :foo}, nil, [])
      ** (KeyError) key :doesnotexist not found in: %Skitter.DSL.ComponentTest.WrongFieldWriteExample{field: :foo}
  """
  defmacro {:state, _, _} <~ value do
    quote do
      unquote(state_var()) = unquote(value)
      nil
    end
  end

  defmacro {field, _, _} <~ value when is_atom(field) do
    quote do
      state <~ Map.replace!(state(), unquote(field), unquote(value))
    end
  end

  defp read?(body) do
    extract_not_empty?(body, fn
      quote(do: state()) -> true
      {:sigil_f, _env, [{:<<>>, _, [_]}, _]} -> true
      _ -> false
    end)
  end

  @doc false
  def write?(body) do
    extract_not_empty?(body, fn
      {:<~, _env, [{name, _, _}, _]} -> name
      _ -> false
    end)
  end

  # Emit
  # ----

  @doc false
  def emit_var, do: quote(do: var!(emit, unquote(__MODULE__)))

  @doc """
  Emit `value` to `port`

  This macro is used to specify `value` should be emitted on `port`. This means that `value`
  will be sent to any components downstream of the current component. This macro should only be
  used inside the body of `defcb/2`. If a previous value was specified for `port`, it is
  overridden.

  ## Examples

  ```
  defcomponent SingleEmitExample do
    defcb emit(value) do
      value ~> some_port
      :foo ~> some_other_port
    end
  end
  ```

      iex> Component.call(SingleEmitExample, :emit, [:bar]).emit
      [some_other_port: [:foo], some_port: [:bar]]
  """
  defmacro value ~> {port, _, _} when is_atom(port) do
    quote do
      unquote(emit_var()) = Keyword.put(unquote(emit_var()), unquote(port), [unquote(value)])
      nil
    end
  end

  @doc """
  Emit several values to `port`

  This macro works like `~>/2`, but emits several output values to the port instead of a single
  value. Each value in the provided `t:Enumerable.t/0` will be sent to downstream components
  individually.

  ## Examples

  ```
  defcomponent MultiEmitExample do
    defcb emit(value) do
      value ~> some_port
      [:foo, :bar] ~>> some_other_port
    end
  end
  ```

      iex> Component.call(MultiEmitExample, :emit, [:bar]).emit
      [some_other_port: [:foo, :bar], some_port: [:bar]]
  """
  defmacro enum ~>> {port, _, _} when is_atom(port) do
    quote do
      unquote(emit_var()) = Keyword.put(unquote(emit_var()), unquote(port), unquote(enum))
      nil
    end
  end

  @doc false
  def emit?(body) do
    extract_not_empty?(body, fn
      {:~>, _env, [_, {_, _, _}]} -> true
      {:~>>, _env, [_, {_, _, _}]} -> true
      _ -> false
    end)
  end

  # defcallback
  # -----------

  @doc """
  Define a callback.

  This macro is used to define a callback function. Using this macro, a callback can be defined
  similar to a regular procedure. Inside the body of the procedure, `~>/2`, `~>>/2` `<~/2` and
  `sigil_f/2` can be used to access the state and to emit output. The macro ensures:

  - The function returns a `t:Skitter.Component.result/0` with the correct state (as updated by
  `<~/2`), emit (as updated by `~>/2` and `~>>/2`) and result (which contains the value of the
  last expression in `body`).

  - `c:Skitter.Component._sk_callback_info/2` and `c:Skitter.Callback._sk_callbacks/0` of the
  component module contains the required information about the defined callback.

  Note that, under the hood, `defcb/2` generates a regular elixir function. Therefore, pattern
  matching may still be used in the argument list of the callback. Attributes such as `@doc` may
  also be used as usual.

  ## Examples

  ```
  defcomponent CbExample do
    defcb simple(), do: nil
    defcb arguments(arg1, arg2), do: arg1 + arg2
    defcb state(), do: counter <~ (~f{counter} + 1)
    defcb emit_single(), do: ~D[1991-12-08] ~> out_port
    defcb emit_multi(), do: [~D[1991-12-08], ~D[2021-07-08]] ~>> out_port
  end
  ```

      iex> Component.callbacks(CbExample)
      #MapSet<[arguments: 2, emit_multi: 0, emit_single: 0, simple: 0, state: 0]>

      iex> Component.callback_info(CbExample, :simple, 0)
      %Info{read?: false, write?: false, emit?: false}

      iex> Component.callback_info(CbExample, :arguments, 2)
      %Info{read?: false, write?: false, emit?: false}

      iex> Component.callback_info(CbExample, :state, 0)
      %Info{read?: true, write?: true, emit?: false}

      iex> Component.callback_info(CbExample, :emit_single, 0)
      %Info{read?: false, write?: false, emit?: true}

      iex> Component.callback_info(CbExample, :emit_multi, 0)
      %Info{read?: false, write?: false, emit?: true}

      iex> Component.call(CbExample, :simple, %{}, nil, [])
      %Result{result: nil, emit: [], state: %{}}

      iex> Component.call(CbExample, :arguments, %{}, nil, [10, 20])
      %Result{result: 30, emit: [], state: %{}}

      iex> Component.call(CbExample, :state, %{counter: 10, other: :foo}, nil, [])
      %Result{result: nil, emit: [], state: %{counter: 11, other: :foo}}

      iex> Component.call(CbExample, :emit_single, %{}, nil, [])
      %Result{result: nil, emit: [out_port: [~D[1991-12-08]]], state: %{}}

      iex> Component.call(CbExample, :emit_multi, %{}, nil, [])
      %Result{result: nil, emit: [out_port: [~D[1991-12-08], ~D[2021-07-08]]], state: %{}}

  ## Mutable state and control flow

  The `<~/2`, `~>/2` and `~>>/2` operators add mutable state to Elixir, which is an immutable
  language. Internally, hidden variables are used to track the current state and values to emit.
  To make this work, the callback DSL rewrites several control flow structures offered by elixir.
  While this approach work well, some limitations are present when the `<~/2`, `~>/2` and `~>>/2`
  operators are used inside control flow structures.

  The use of these operators is supported in the following control flow constructs:

  * `Kernel.if/2`
  * `Kernel.unless/2`
  * `Kernel.SpecialForms.try/1`
  * `Kernel.SpecialForms.cond/1`
  * `Kernel.SpecialForms.case/2`
  * `Kernel.SpecialForms.receive/1`

  With the exception of `Kernel.SpecialForms.try/1`, all of these control flow constructs behave
  as expected. Said otherwise, state updates performed inside any of these constructs are
  reflected outside of the control flow construct.

  ### `try`

  The behaviour of `try` blocks is not as straightforward due to implementation limitations. We
  describe the different behaviours that may occur below.

  ```
  defcb simple(fun) do
    try do
      pre <~ :modified
      res = fun.()
      post <~ :modified
      :emit ~> out
      res
    rescue
      RuntimeError ->
        x <~ :modified
        :rescue
    catch
      _ ->
        :emit ~> out
        :catch
    end
  end
  ```

  If no exception is raised or no value is thrown, updates performed inside the `do` block will
  always be visible:

      iex> Component.call(TryExample, :simple, %{pre: nil, post: nil}, nil, [fn -> :foo end])
      %Result{state: %{pre: :modified, post: :modified}, result: :foo, emit: [out: [:emit]]}

  However, when an exception is raised or a value is thrown, any updates performed inside the `do`
  block are discarded:

      iex> Component.call(TryExample, :simple, %{pre: nil, post: nil, x: nil}, nil, [fn -> raise RuntimeError end])
      %Result{state: %{pre: :nil, post: :nil, x: :modified}, result: :rescue, emit: []}

      iex> Component.call(TryExample, :simple, %{pre: nil, post: nil}, nil, [fn -> throw :foo end])
      %Result{state: %{pre: :nil, post: :nil}, result: :catch, emit: [out: [:emit]]}

  As shown above, updates inside the `catch` or `rescue` clauses are reflected in the final
  result.

  #### `else` and `after`

  ```
  defcb with_else(fun) do
    try do
      pre <~ :modified
      res = fun.()
      post <~ :modified
      :emit ~> out
      res
    rescue
      RuntimeError ->
        :rescue
    else
      res ->
        x <~ :modified
        res
    end
  end
  ```

  Updates inside the `do` block _are_ reflected in the `else` block:

      iex> Component.call(TryExample, :with_else, %{pre: nil, post: nil, x: nil}, nil, [fn -> :foo end])
      %Result{state: %{pre: :modified, post: :modified, x: :modified}, result: :foo, emit: [out: [:emit]]}

  Updates inside the `after` block are ignored:

  ```
  defcb with_after(fun) do
    try do
      pre <~ :modified
      res = fun.()
      post <~ :modified
      :emit ~> out
      res
    rescue
      RuntimeError -> :rescue
    after
      x <~ :modified
      :ignored
    end
  end
  ```

      iex> Component.call(TryExample, :with_after, %{pre: nil, post: nil, x: nil}, nil, [fn -> :foo end])
      %Result{state: %{pre: :modified, post: :modified, x: nil}, result: :foo, emit: [out: [:emit]]}

  In short, updates are preserved during the normal flow of an operation (i.e. when no values are
  raised or thrown), updates inside `after` are ignored.
  """
  defmacro defcb(clause, do: body) do
    body = __MODULE__.ControlFlowOperators.rewrite_special_forms(body)
    info = %Info{read?: read?(body), write?: write?(body), emit?: emit?(body)} |> Macro.escape()
    {name, args, guards} = AST.decompose_clause(clause)
    arity = length(args)

    quote do
      @doc false
      @_sk_callbacks {{unquote(name), unquote(arity)}, unquote(info)}
      def unquote(AST.build_clause(name, [state_var(), config_var()] ++ args, guards)) do
        import unquote(__MODULE__), only: [state: 0, config: 0, sigil_f: 2, ~>: 2, ~>>: 2, <~: 2]
        use unquote(__MODULE__.ControlFlowOperators)

        unquote(emit_var()) = []

        result = unquote(body)

        %Skitter.Component.Callback.Result{
          result: result,
          state: unquote(state_var()),
          emit: unquote(emit_var())
        }
      end
    end
  end

  defp build_signature(name, args) do
    quote do
      unquote(name)(unquote(state_var()), unquote(config_var()), unquote_splicing(args))
    end
  end

  defp build_clause(signature, {:when, _, [_, guards]}) do
    quote(do: unquote(signature) when unquote(guards))
  end

  defp build_clause(signature, _), do: quote(do: unquote(signature))
end
