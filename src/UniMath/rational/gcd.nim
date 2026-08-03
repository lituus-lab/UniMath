# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Greatest common divisor and least common multiple for any integer-like `T`
## supporting `mod`, `<`, `-`, `==` (built-in integers and `BigInt`). The
## Euclidean loop uses only `mod`, so it never negates `MinInt`; the sign is
## normalized on the result, where negating `MinInt` raises `OverflowDefect`
## under a forced `overflowChecks` push (a no-op for `BigInt`, whose `-` is a
## user proc). Bodies only — no inline `ensure:`: a divisibility postcondition
## would call `T`'s contracted `cmp`/`divMod` from an ensure (recursion
## doctrine); the identities are exercised by the rational tests.
import contracts

func gcd*[T](a, b: T): T {.contractual.} =
  ## Euclidean GCD of `a` and `b`, always non-negative. Raises `OverflowDefect`
  ## only when the gcd itself is `MinInt` (e.g. `gcd(MinInt, 0)`), a magnitude
  ## that does not fit `T`.
  body:
    var u = a
    var v = b
    let zero = default(T)
    while v != zero:
      let r = u mod v
      u = v
      v = r
    if u < zero:
      {.push overflowChecks: on.}
      u = -u
      {.pop.}
    return u

func lcm*[T](a, b: T): T {.contractual.} =
  ## `|a * b| / gcd(a, b)`, dividing before multiplying to limit intermediate
  ## growth. Zero is returned when either operand is zero. The multiplication
  ## and the `MinInt` negation run under a forced `overflowChecks` push so an
  ## unrepresentable product surfaces as `OverflowDefect` even in release (a
  ## no-op for `BigInt`, whose `*`/`-` are user procs).
  body:
    let zero = default(T)
    if a == zero or b == zero:
      return zero
    let g = gcd(a, b)
    var res: T
    {.push overflowChecks: on.}
    res = (a div g) * b
    if res < zero:
      res = -res
    {.pop.}
    return res
