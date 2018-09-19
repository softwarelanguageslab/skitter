# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule WorkflowTest do
  use ExUnit.Case
  doctest Workflow

  test "greets the world" do
    assert Workflow.hello() == :world
  end
end