# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Callback do
  @moduledoc """
  Callback definition DSL.

  This module offers a DSL which enables the definition of `Skitter.Callback` inside a module. In
  order to use this module, `use Skitter.DSL.Callback` needs to be added to the module definition.
  Afterwards, `defcb/2` can be used to define callbacks. Using this macro ensures the correct
  information is automatically added to `c:Skitter.Callback._sk_callback_info/2` and
  `c:Skitter.Callback._sk_callback_list/0`.

  Note that it is generally not needed to `import` or `use` this module manually, as
  `Skitter.DSL.Component.defcomponent/3` and `Skitter.DSL.Strategy.defstrategy/3` do this
  automatically.
  """

  alias Skitter.Callback.Info

  # ------------------- #
  # Behaviour Callbacks #
  # ------------------- #

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [defcb: 2]

      @behaviour Skitter.Callback
      @before_compile {unquote(__MODULE__), :generate_behaviour_callbacks}
      Module.register_attribute(__MODULE__, :_sk_callbacks, accumulate: true)
    end
  end

  @doc false
  defmacro generate_behaviour_callbacks(env) do
    names =
      env.module
      |> Module.get_attribute(:_sk_callbacks)
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()

    metadata =
      env.module
      |> Module.get_attribute(:_sk_callbacks)
      |> Enum.reduce(%{}, fn {{name, arity}, info}, map ->
        Map.update(map, {name, arity}, info, fn s = %Info{} ->
          %{
            s
            | read: Enum.uniq(s.read ++ info.read),
              write: Enum.uniq(s.write ++ info.write),
              publish: Enum.uniq(s.publish ++ info.publish)
          }
        end)
      end)
      |> Macro.escape()

    quote bind_quoted: [names: names, metadata: metadata] do
      @impl true
      def _sk_callback_list, do: unquote(names)

      # Prevent a warning if no callbacks are defined
      @impl true
      def _sk_callback_info(nil, 0), do: %Skitter.Callback.Info{}

      for {{name, arity}, info} <- metadata do
        def _sk_callback_info(unquote(name), unquote(arity)), do: unquote(Macro.escape(info))
      end
    end
  end

  # -------------- #
  # Callback State #
  # -------------- #

  defp extract(body, verify) do
    body
    |> Macro.prewalk(MapSet.new(), fn
      node, acc -> if el = verify.(node), do: {node, MapSet.put(acc, el)}, else: {node, acc}
    end)
    |> elem(1)
    |> Enum.to_list()
  end

  # State
  # -----

  @doc """
  Read the state of a field.

  This macro reads the current value of `field` in the state passed to `Skitter.Callback.call/4`.

  This macro should only be used inside the body of `defcb/2`.

  ## Examples

      iex> defmodule ReadExample do
      ...>   use Skitter.DSL.Callback
      ...>   defcb read(), do: ~f{field}
      ...> end
      iex> Callback.call(ReadExample, :read, %{field: 5}, []).result
      5
      iex> Callback.call(ReadExample, :read, %{field: :foo}, []).result
      :foo
  """
  defmacro sigil_f({:<<>>, _, [str]}, _), do: str |> String.to_existing_atom() |> state_var()

  @doc """
  Update the state of a field.

  This macro should only be used inside the body of `defcallback/4`. It updates the value of
  `field` to `value` and returns `value` as its result. Note that `field` needs to exist inside
  `state`. If it does not exist, a `KeyError` will be raised.

  ## Examples

      iex> defmodule WriteExample do
      ...>   use Skitter.DSL.Callback
      ...>   defcb write(), do: field <~ :bar
      ...> end
      iex> Callback.call(WriteExample, :write, %{field: :foo}, []).state[:field]
      :bar
      iex> Callback.call(WriteExample, :write, %{field: :foo}, [])
      %Result{result: :bar, state: %{field: :bar}, publish: []}
      iex> Callback.call(WriteExample, :write, %{}, [])
      ** (KeyError) key :field not found
  """
  defmacro {field, _, _} <~ value when is_atom(field) do
    quote do
      unquote(state_var(field)) = unquote(value)
    end
  end

  @doc false
  def state_var(atom) do
    context = __MODULE__.State
    quote(do: var!(unquote(Macro.var(atom, context)), unquote(context)))
  end

  defp state_init(fields, state_arg) do
    for atom <- fields do
      quote do
        unquote(state_var(atom)) = Map.fetch!(unquote(state_arg), unquote(atom))
      end
    end
  end

  defp state_return(fields, state_arg) do
    writes = for atom <- fields, do: {atom, state_var(atom)}

    quote do
      %{unquote(state_arg) | unquote_splicing(writes)}
    end
  end

  defp get_reads(body) do
    extract(body, fn
      {:sigil_f, _env, [{:<<>>, _, [field]}, _]} -> String.to_existing_atom(field)
      _ -> false
    end)
  end

  @doc false
  def get_writes(body) do
    extract(body, fn
      {:<~, _env, [{name, _, _}, _]} -> name
      _ -> false
    end)
  end

  # Publish
  # -------

  @doc """
  Publish `value` to `port`

  This macro is used to specify `value` should be published on `port`. It should only be used
  inside the body of `defcb/2`. If a previous value was specified for `port`, it is overridden.

  ## Examples

      iex> defmodule PublishExample do
      ...>   use Skitter.DSL.Callback
      ...>   defcb publish(value) do
      ...>     value ~> some_port
      ...>     ~f{field} ~> some_other_port
      ...>   end
      ...> end
      iex> Callback.call(PublishExample, :publish, %{field: :foo}, [:bar]).publish
      [some_other_port: :foo, some_port: :bar]
  """
  defmacro value ~> {port, _, _} when is_atom(port) do
    quote do
      value = unquote(value)
      unquote(publish_var()) = Keyword.put(unquote(publish_var()), unquote(port), value)
      value
    end
  end

  @doc false
  def publish_var, do: quote(do: var!(publish, unquote(__MODULE__)))

  defp publish_init(_), do: quote(do: unquote(publish_var()) = [])
  defp publish_return(_), do: quote(do: unquote(publish_var()))

  @doc false
  def get_published(body) do
    extract(body, fn
      {:~>, _env, [_, {name, _, _}]} -> name
      _ -> false
    end)
  end

  # ----------- #
  # defcallback #
  # ----------- #

  @doc """
  Define a callback.

  This macro is used to define a callback function. Using this macro, a callback can be defined
  similar to a regular procedure. Inside the body of the procedure, `~>/2`, `<~/2` and `sigil_f/2`
  can be used to access the state and to publish output. The macro ensures:

  - The function returns a `t:Skitter.Callback.result/0` with the correct state (as updated by
  `<~/2`), publish (as updated by `~>/2`) and result (which contains the value of the last
  expression in `body`).

  - `c:Skitter.Callback._sk_callback_info/2` and `c:Skitter.Callback._sk_callback_list/0` of the
  parent module contains the required information about the defined callback.

  Note that, under the hood, `defcb/2` generates a regular elixir function. Therefore, pattern
  matching may still be used in the argument list of the callback. Attributes such as `@doc` may
  also be used as usual.

  ## Examples

      iex> defmodule CbExample do
      ...>   use Skitter.DSL.Callback
      ...>
      ...>   defcb simple(), do: nil
      ...>   defcb arguments(arg1, arg2), do: arg1 + arg2
      ...>   defcb state(), do: counter <~ ~f{counter} + 1
      ...>   defcb publish(), do: ~D[1991-12-08] ~> out_port
      ...> end
      iex> Callback.info(CbExample, :simple, 0)
      %Info{read: [], write: [], publish: []}
      iex> Callback.info(CbExample, :arguments, 2)
      %Info{read: [], write: [], publish: []}
      iex> Callback.info(CbExample, :state, 0)
      %Info{read: [:counter], write: [:counter], publish: []}
      iex> Callback.info(CbExample, :publish, 0)
      %Info{read: [], write: [], publish: [:out_port]}
      iex> Callback.call(CbExample, :simple, %{}, [])
      %Result{result: nil, publish: [], state: %{}}
      iex> Callback.call(CbExample, :arguments, %{}, [10, 20])
      %Result{result: 30, publish: [], state: %{}}
      iex> Callback.call(CbExample, :state, %{counter: 10, other: :foo}, [])
      %Result{result: 11, publish: [], state: %{counter: 11, other: :foo}}
      iex> Callback.call(CbExample, :publish, %{}, [])
      %Result{result: ~D[1991-12-08], publish: [out_port: ~D[1991-12-08]], state: %{}}
  """
  defmacro defcb(signature, do: body) do
    body = __MODULE__.ControlFlowOperators.rewrite_special_forms(body)
    {name, args} = Macro.decompose_call(signature)
    published = get_published(body)
    writes = get_writes(body)
    reads = get_reads(body)

    state_var = Macro.var(:state, __MODULE__)
    arity = length(args)

    info = %Info{read: reads, write: writes, publish: published} |> Macro.escape()

    quote do
      @_sk_callbacks {{unquote(name), unquote(arity)}, unquote(info)}
      def unquote(name)(unquote(state_var), unquote_splicing(args)) do
        import unquote(__MODULE__), only: [sigil_f: 2, ~>: 2, <~: 2]
        use unquote(__MODULE__.ControlFlowOperators)

        unquote(state_init(reads, state_var))
        unquote(publish_init(published))

        result = unquote(body)

        %Skitter.Callback.Result{
          result: result,
          state: unquote(state_return(writes, state_var)),
          publish: unquote(publish_return(body))
        }
      end
    end
  end

  # ------------- #
  # Compile Hooks #
  # ------------- #

  # Code to insert quoted code to ensure a callback exists or to add one
end
