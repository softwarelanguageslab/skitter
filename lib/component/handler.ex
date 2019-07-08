# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Handler do
  @moduledoc """
  Reactive component handler utilities.

  Handlers determine the behaviour of a component at compile -and runtime.
  This module documents the handler type, and documents the hooks a handler can
  use to determine the behaviour of a component. Finally, it provides the
  `defhandler/2` macro, which can be used to implement a component which can
  act as a component handler.

  # TODO: Allow workflow handlers
  """
  alias Skitter.Component.MetaHandler, as: Meta
  alias Skitter.{Component, Workflow, Registry}

  @typedoc """
  Reactive component handler type.

  A reactive component handler is one of the following:
  - A meta-component
  - A workflow that consists of meta-components
  - `Meta`. When this handler is used, it specifies that a meta-component is
  being defined. A component which uses the `Meta` handler can be used as a
  handler for other components.
  """
  @type t :: Meta | Component.t() | Workflow.t()

  # --------- #
  # Utilities #
  # --------- #

  @doc false
  def valid?(Meta), do: true
  def valid?(h = %Component{}), do: Component.meta?(h)
  def valid?(_), do: false

  @doc false
  def expand(Meta), do: Meta
  def expand(handler = %Component{handler: Meta}), do: handler

  def expand(name) when is_atom(name) do
    case Registry.get(name) do
      nil -> throw {:error, :invalid_name, name}
      handler -> expand(handler)
    end
  end

  def expand(any), do: throw({:error, :invalid_handler, any})

  # ----- #
  # Hooks #
  # ----- #

  @doc section: :hooks
  def on_define(c = %Component{handler: Meta}), do: Meta.on_define(c)

  def on_define(c = %Component{handler: handler}) do
    # TODO: figure out state?
    Component.call(handler, :on_define, %{}, [c]).result
  end

  # ------ #
  # Macros #
  # ------ #

  @doc """
  Define a meta-component.

  This macro is syntactic sugar for defining a component using
  `Skitter.Component.defcomponent/3`. The handler and ports of this component
  do not need to be specified, as they are defined by this macro.
  The body of the component is defined using the DSL offered by
  `Skitter.Component.defcomponent/3`.
  """
  @doc section: :dsl
  defmacro defhandler(name \\ nil, do: body) do
    body =
      case body do
        {:__block__, _, []} -> nil
        any -> any
      end

    quote do
      import Skitter.Component

      defcomponent unquote(name), in: [] do
        alias Skitter.Component
        alias Skitter.Component.{Callback, Instance}

        import Skitter.Component.Handler.Utils
        import Skitter.Component.Callback, only: [defcallback: 4]

        handler(Meta)
        unquote(body)
      end
    end
  end
end
