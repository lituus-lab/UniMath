# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## String formatting for `Complex`. `$` is the rectangular form
## `"<re><signed im>i"` — `0.0+1.0i`, `1.0-2.0i` — delegating to the
## component's own `$`. The sign of the imaginary part is read off that
## rendering rather than compared numerically: `$` must work for a component
## with no order, and `Rational`'s `$` already carries the sign in `num`.
import ./complex_type

func `$`*[T](z: Complex[T]): string =
  mixin `$`
  let im = $z.im
  let sep = if im.len > 0 and im[0] == '-': "" else: "+"
  $z.re & sep & im & "i"
