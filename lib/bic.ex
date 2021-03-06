# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.BIC do
  @moduledoc """
  Shorthands for using BICs.

  This module defines various macros which can be used to use the various built-in components in
  skitter workflows.
  """

  @doc """
  `Skitter.BIC.Map` node.

  Inserts a `Skitter.BIC.Map` `Skitter.DSL.Workflow.node/2` in the workflow. The argument passed
  to this macro is passed as an argument to `Skitter.BIC.Map`, other options (`as:`, `with:`)
  should be passed as a second, optional argument.
  """
  defmacro map(func, opts \\ []) do
    opts = [args: func] ++ opts
    quote(do: node(Skitter.BIC.Map, unquote(opts)))
  end

  @doc """
  `Skitter.BIC.FlatMap` node.

  Like `map/2`, but with `Skitter.BIC.FlatMap`.
  """
  defmacro flat_map(func, opts \\ []) do
    opts = [args: func] ++ opts
    quote(do: node(Skitter.BIC.FlatMap, unquote(opts)))
  end

  @doc """
  `Skitter.BIC.Filter` node.

  Inserts a `Skitter.BIC.Filter` `Skitter.DSL.Workflow.node/2` in the workflow. The argument
  passed to this macro is passed as an argument to `Skitter.BIC.Filter`, other options (`as:`,
  `with:`) should be passed as a second, optional argument.
  """
  defmacro filter(func, opts \\ []) do
    opts = [args: func] ++ opts
    quote(do: node(Skitter.BIC.Filter, unquote(opts)))
  end

  @doc """
  `Skitter.BIC.KeyBy` node.

  Inserts a `Skitter.BIC.KeyBy` `Skitter.DSL.Workflow.node/2` in the workflow. The provided `func`
  will be passed as an argument to `Skitter.BIC.KeyBy`. Other arguments (`as:`, `with:`) should be
  passed as the optional, third argument.
  """
  defmacro key_by(func, opts \\ []) do
    opts = [args: func] ++ opts
    quote(do: node(Skitter.BIC.KeyBy, unquote(opts)))
  end

  @doc """
  `Skitter.BIC.KeyedReduce` node.

  Inserts a `Skitter.BIC.KeyedReduce` `Skitter.DSL.Workflow.node/2` in the workflow. The `func` and
  `initial` arguments passed to this macro are passed as arguments to `Skitter.BIC.KeyedReduce`.
  Other options (`as:`, `with:`) can be passed as a third argument.
  """
  defmacro keyed_reduce(func, initial, opts \\ []) do
    opts = [args: {func, initial}] ++ opts
    quote(do: node(Skitter.BIC.KeyedReduce, unquote(opts)))
  end

  @doc """
  `Skitter.BIC.Print` node.

  Insert a `Skitter.BIC.Print` node in the workflow. The argument passed to this macro is passed
  as the print label described in the component documentation. Workflow options (`as`, `with`) can
  be passed as the optional second argument.
  """
  defmacro print(label \\ nil, opts \\ []) do
    opts = [args: label] ++ opts
    quote(do: node(Skitter.BIC.Print, unquote(opts)))
  end

  @doc """
  `Skitter.BIC.Send` node.

  Insert a `Skitter.BIC.Send` sink in the workflow. The argument passed to this macro is passed
  as the pid described in the component documentation. Workflow options (`as`, `with`) can
  be passed as the optional second argument. When no argument is provided, `self()` will be used.
  """
  defmacro send_sink(pid \\ quote(do: self()), opts \\ []) do
    opts = [args: pid] ++ opts
    quote(do: node(Skitter.BIC.Send, unquote(opts)))
  end

  @doc """
  Tcp source node.

  Inserts a `Skitter.BIC.TCPSource` node in the workflow. The address and ports passed to this
  argument will be passed as arguments to `Skitter.BIC.TCPSource`. Provided options are passed to
  the workflow.
  """
  defmacro tcp_source(address, port, opts \\ []) do
    opts = [args: [address: address, port: port]] ++ opts
    quote(do: node(Skitter.BIC.TCPSource, unquote(opts)))
  end

  @doc """
  Stream source node.

  Inserts a `Skitter.BIC.StreamSource` node in the workflow. The provided `enum` is passed as an
  argument to `Skitter.BIC.StreamSource`. `opts` are passed as options to the workflow.
  """
  defmacro stream_source(enum, opts \\ []) do
    opts = [args: enum] ++ opts
    quote(do: node(Skitter.BIC.StreamSource, unquote(opts)))
  end

  @doc """
  Message source node.

  Inserts a `Skitter.BIC.MessageSource` node in the workflow. Any options are passed to the
  workflow.
  """
  defmacro msg_source(opts \\ []) do
    quote(do: node(Skitter.BIC.MessageSource, unquote(opts)))
  end
end
