# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Rational arithmetic: `+`, `-`, `*`, `/`, unary `-`, `abs`. Multiplication
## cross-simplifies before multiplying; addition finds the common denominator via
## `gcd` to keep intermediates small. `overflowChecks` is forced on so a result
## that does not fit a bounded `T` raises `OverflowDefect` in every build mode
## (no-op for `BigInt`; callers needing unbounded exact arithmetic use
## `Rational[BigInt]`). Bodies only — no inline `ensure:`: the `den > 0` and
## sign postconditions compare `T`'s fields via the contracted `cmp` for
## `BigInt` storage (recursion doctrine); the invariants are enforced by
## `initRational`/`simplify` and exercised by the rational tests.
import ../arithmetic
import ./gcd
import ./rational_type
import contracts

{.push overflowChecks: on.}

func `*`*[T](x, y: Rational[T]): Rational[T] {.contractual.} =
  ## Cross-simplifies before multiplying to avoid large intermediate products.
  body:
    let g1 = gcd(x.num, y.den)
    let g2 = gcd(y.num, x.den)
    result.num = (x.num div g1) * (y.num div g2)
    result.den = (x.den div g2) * (y.den div g1)

func `/`*[T](x, y: Rational[T]): Rational[T] {.contractual.} =
  ## `x * (1/y)`. Division by zero raises `DivByZeroDefect` (body guard,
  ## survives release).
  body:
    let zero = default(T)
    if y.num == zero:
      raise newException(DivByZeroDefect, "Rational division by zero")
    var yInv: Rational[T]
    yInv.num = y.den
    yInv.den = y.num
    if yInv.den < zero: # restore the positive-denominator invariant
      yInv.num = -yInv.num
      yInv.den = -yInv.den
    return x * yInv

func `+`*[T](x, y: Rational[T]): Rational[T] {.contractual.} =
  ## Adds via the smallest common denominator (`gcd` of denominators) to
  ## minimize overflow.
  body:
    let g = gcd(x.den, y.den)
    let one = x.den div x.den
    if g == one:
      # Coprime denominators: cross-multiply; initRational reduces the result.
      return initRational(x.num * y.den + y.num * x.den, x.den * y.den)
    let dDivG = y.den div g
    let bDivG = x.den div g
    return initRational(x.num * dDivG + y.num * bDivG, x.den * dDivG)

func `-`*[T](x, y: Rational[T]): Rational[T] {.contractual.} =
  ## `x + (-y)`.
  body:
    var negY = y
    negY.num = -negY.num
    return x + negY

func `-`*[T](x: Rational[T]): Rational[T] {.contractual.} =
  ## Unary negation.
  body:
    result = x
    result.num = -result.num

func abs*[T](x: Rational[T]): Rational[T] {.contractual.} =
  ## Absolute value (non-negative magnitude).
  body:
    result = x
    let zero = default(T)
    if result.num < zero:
      result.num = -result.num

{.pop.}
