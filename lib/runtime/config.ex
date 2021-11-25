# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Config do
  @moduledoc false
  # Convenience functions to obtain data from the Skitter application environment.

  @doc """
  Get configuration `key` from the application environment.

  Return `default` if no value is specified.
  """
  def get(key, default \\ nil), do: Application.get_env(:skitter, key, default)

  @doc """
  Store `value` under `key` in the application environment.

  Should be used when setting values at runtime.
  """
  def put(key, value), do: Application.put_env(:skitter, key, value, persistent: true)
end
