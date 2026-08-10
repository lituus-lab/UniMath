# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Complex equality. Deliberately no `<`, `<=`, `cmp` or `sign`: the complex
## field admits no order compatible with its arithmetic, and defining one would
## let `Complex` satisfy `OrderedField`/`RealField` — which is exactly what
## keeps a `Vector[D, Complex]` from silently taking a wrong Euclidean length
## through `sqrt(x*x + y*y)` instead of `sqrt(|x|^2 + |y|^2)`.
##
## Callers ordering complex values by magnitude compare `norm2` (exact) rather
## than `abs` (a square root, hence approximate on every backend).
import ../arithmetic
import ./complex_type

func `==`*[T](x, y: Complex[T]): bool {.inline.} =
  mixin `==`
  x.re == y.re and x.im == y.im

# `!=` comes from system, derived from `==`.

func `==`*[T](x: Complex[T], s: T): bool {.inline.} =
  ## A complex equals a scalar only when its imaginary part is exactly zero.
  mixin `==`
  x.im == fromInt(T, 0) and x.re == s

func `==`*[T](s: T, x: Complex[T]): bool {.inline.} =
  x == s
