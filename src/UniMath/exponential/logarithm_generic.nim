# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Generic `ln(z)` for any positive `z`, via the area-hyperbolic-tangent
## series. Writing `z = (1+x)/(1-x)` gives `x = (z-1)/(z+1)` and
## `ln(z) = 2*(x + x^3/3 + x^5/5 + ...)`, which converges for every positive
## `z` (fast near 1).
import contracts
import ../arithmetic

func lnGeneric*[F: OrderedField](z: F, terms: int = 15): F {.contractual.} =
  ## `ln(z)` for any positive `OrderedField`.
  ##
  ## Domain guard (body `raise`, survives `-d:release`): the real logarithm is
  ## undefined for `z <= 0`. Bounded by `OrderedField` because the guard needs
  ## a total order. No inline `ensure:` (recursion doctrine) — the sign-of-`x`
  ## and `ln(1) == 0` identities are verified externally against the oracle.
  body:
    let one = one(F)
    let z0 = zero(F)

    if z <= z0:
      raise newException(ValueError, "lnGeneric: input <= 0 (real log undefined)")

    let x = (z - one) / (z + one)
    let x2 = x * x

    var resultVal = x
    var term = x

    for n in 1 ..< terms:
      term = term * x2
      resultVal = resultVal + (term / fromInt(F, 2 * n + 1))

    return fromInt(F, 2) * resultVal


