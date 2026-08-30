# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Generic `ln(z)` for any positive `z`, via the area-hyperbolic-tangent
## series. Writing `z = (1+x)/(1-x)` gives `x = (z-1)/(z+1)` and
## `ln(z) = 2*(x + x^3/3 + x^5/5 + ...)`.
##
## The series converges for every positive `z` only in the limit: `x` tends to
## 1 as `z` grows, and the term count needed grows with it — measured for
## twelve digits, 15 terms at `z = 2`, 200 at `z = 10`, 20 000 at `z = 1e3`,
## and not reached at 100 000 for `z = 1e6`. Past the default the result is
## wrong rather than refused. Scale into range first (`ln(m*2^k) = ln m +
## k*ln 2`); this is a logarithm for arguments near 1, not a general one.
##
## `ln1pGeneric(x)` is `ln(1+x)` for an `x` that may be far smaller than 1,
## where forming `1 + x` first would discard every digit of `x` below the
## leading one of `1`.
import contracts
import ../arithmetic

func lnGeneric*[F: OrderedField](z: F, terms: int = 15): F {.contractual.} =
  ## `ln(z)` for any positive `OrderedField`.
  ##
  ## `terms` is a budget, not a target: the caller owns convergence. See the
  ## module header for the measured cost — the default holds near `z = 1` and
  ## silently does not past `z = 10`.
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

func ln1pGeneric*[F: OrderedField](x: F, terms: int = 15): F {.contractual.} =
  ## `ln(1 + x)` without ever forming `1 + x`.
  ##
  ## The same atanh series, reparametrised: `1 + x = (1+u)/(1-u)` gives
  ## `u = x / (2 + x)`, so `ln(1+x) = 2*(u + u^3/3 + u^5/5 + ...)` and `x`
  ## reaches the result at full precision however small it is. Computing
  ## `lnGeneric(one + x)` instead rounds `1 + x` to `1` once `x` falls below
  ## the component's epsilon, and loses a digit of `x` for every power of two
  ## between them before that.
  ##
  ## `u` carries the convergence and grows with `x`: near zero the series is
  ## done in a few terms, while a large `x` drives `u` toward 1 and needs a
  ## `terms` well past the default before the tail is negligible. A caller that
  ## admits a large argument should size `terms` from its own precision.
  ##
  ## Domain guard (body `raise`, survives `-d:release`): `1 + x > 0`, i.e.
  ## `x > -1`. Bounded by `OrderedField` for the guard. No inline `ensure:`
  ## (recursion doctrine); the `ln1p(0) == 0` and `exp(ln1p(x)) == 1+x`
  ## identities are verified externally.
  body:
    let one = one(F)
    let two = fromInt(F, 2)

    if x <= -one:
      raise newException(ValueError,
        "ln1pGeneric: 1 + x <= 0 (real log undefined)")

    # `u` is in (-1, 1) for every admissible `x`, so the series always
    # converges; it is at its fastest exactly where this function is needed.
    let u = x / (two + x)
    let u2 = u * u

    var resultVal = u
    var term = u

    for n in 1 ..< terms:
      term = term * u2
      resultVal = resultVal + (term / fromInt(F, 2 * n + 1))

    return two * resultVal


