# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Interval sub-umbrella: type, directed-rounding arithmetic, comparison, and
## transcendentals. A self-contained leaf — imports only `contracts` and
## `std/math` (plus its own submodules), nothing from the other UniMath
## packages.
import ./interval/interval_type
import ./interval/arithmetic
import ./interval/comparison
import ./interval/functions
import ./interval/formatting
export interval_type, arithmetic, comparison, functions, formatting

# Implicit converters are opt-in via `-d:umConverters`: implicit conversions
# across packages collide, so the canonical construction is the explicit
# `initInterval`.
when defined(umConverters):
  converter toInterval*(val: float64): Interval[float64] =
    initInterval(val)

  converter toInterval*(val: int): Interval[float64] =
    initInterval(float64(val))
