# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Config

config :logger, :console,
  format: "\n[$time][$level$levelpad] $message",
  device: :standard_error,
  metadata: :all

config :skitter, mode: :local

import_config "#{Mix.env()}.exs"
