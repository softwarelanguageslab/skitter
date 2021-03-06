# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Component, only: :macros

defcomponent Skitter.BIC.Print, in: _, out: _, strategy: Skitter.BIS.ImmutableLocal do
  @componentdoc """
  Print component.

  This component print any data element it receives and emits the received value on its out port.
  This makes it possible to insert this component in the middle of a data processing
  pipeline for debugging purposes.

  A single string should be provided as an argument, this string will be used as a prefix for the
  printed output.
  """
  defcb conf(str), do: str

  defcb react(val) do
    case config() do
      nil -> IO.inspect(val)
      label -> IO.inspect(val, label: label)
    end
    ~> _
  end
end
