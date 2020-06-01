# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

[
  line_length: 80,
  inputs: ["mix.exs", "{config,lib,test}/**.{ex,exs}"],
  locals_without_parens: [
    throw: :*,
    # DSL
    defcomponent: :*,
    defworkflow: :*,
    strategy: :*,
    instance: :*,
    fields: :*,
    # Logger
    info: :*,
    debug: :*,
    warn: :*,
    error: :*
  ]
]

