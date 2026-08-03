# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Generic square root via Newton-Raphson: `x_{k+1} = (x_k + n / x_k) / 2`.
## Convergence is quadratic once the iterate is close. From the seed `x0 = n`
## the iterate roughly halves toward `sqrt(n)` each step, so reaching the
## quadratic regime is `O(log n)` (not `log2(log2(n))`); the cap must cover that
## linear phase, and a relative-tolerance early exit stops the loop as soon as
## two successive iterates agree.
import contracts
import ../arithmetic

func sqrtNewtonGeneric*[F: OrderedField](n: F,
    iterations: int = 20): F {.contractual.} =
  ## Square root for any `OrderedField` (float64, `BigFloat`, `Rational`,
  ## `Fixed`). `n == 0` returns `0`.
  ##
  ## Domain guard (body `raise`, survives `-d:release`): `sqrt` is undefined on
  ## the reals for `n < 0`. Bounded by `OrderedField` because the sign guard
  ## needs a total order. No inline `ensure:` — `result >= zero(F)` resolves,
  ## for `BigFloat`/`Rational`/`Fixed`, to the contracted `cmp` (re-entrant
  ## from an ensure); the non-negativity and zero-iff-zero identities are
  ## exercised by the test suite.
  body:
    let z0 = zero(F)
    if n < z0:
      raise newException(ValueError, "sqrtNewton: input is negative (sqrt undefined)")
    if n == z0:
      return z0

    # Seed from n: Newton for sqrt is globally convergent from any positive
    # seed; the cap covers the slow approach phase.
    var x = n
    let half = fromInt(F, 1) / fromInt(F, 2)

    for k in 1 .. iterations:
      let prev = x
      x = half * (x + (n / x))
      # Relative-tolerance early exit: stop when the iterate stabilises.
      # `prev == x` is exact on Fixed/Rational and ulp-stable on Float.
      if k > 1 and prev == x:
        break

    return x
