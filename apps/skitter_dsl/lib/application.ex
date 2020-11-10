# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Application do
  @moduledoc false

  use Application
  alias Skitter.DSL

  @impl true
  def start(_type, _args) do
    children = [
      DSL.Registry
    ]

    opts = [strategy: :one_for_one, name: Skitter.Remote.Supervisor]
    Supervisor.start_link(children, opts)
  end
end