# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## String formatting for `Rational`. `$` is `"num/den"`, delegating to the
## scalar's own `$` -- the exact fraction, matching std/rationals (not an
## approximation).
import ./rational_type

func `$`*[T](a: Rational[T]): string =
  mixin `$`
  $a.num & "/" & $a.den
