# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Taylor/Maclaurin series for `exp(x)` and `ln(1+x)`, generic over any
## `Field` / `OrderedField`. Integer coefficients come from the uniform
## `fromInt(F, n)` construction.
import contracts
import ../arithmetic

func expTaylor*[F: Field](x: F, terms: int = 15): F {.contractual.} =
  ## `exp(x) = 1 + x + x^2/2! + x^3/3! + ...` for any `Field` (float64,
  ## `BigFloat`, `Rational`, `Fixed`).
  ##
  ## No inline `ensure:` (recursion doctrine) — `x == zero(F)` / `result ==
  ## one(F)` resolve, for `BigFloat`/`Rational`, to the contracted `cmp`
  ## (re-entrant from an ensure); the `expTaylor(0) == 1` identity is
  ## exercised by the test suite.
  body:
    var resultVal = fromInt(F, 1)
    var term = fromInt(F, 1)

    for n in 1 ..< terms:
      term = term * x
      term = term / fromInt(F, n)
      resultVal = resultVal + term

    return resultVal

func lnTaylor*[F: OrderedField](x: F, terms: int = 15): F {.contractual.} =
  ## `ln(1+x) = x - x^2/2 + x^3/3 - ...`, converges for `|x| < 1`.
  ##
  ## Domain guard (body `raise`, survives `-d:release`): `ln(1+x)` is
  ## undefined for `1+x <= 0` (`x <= -1`), where the alternating series also
  ## diverges. Bounded by `OrderedField` so the `<=` guard is concept-guaranteed.
  ##
  ## No inline `ensure:` (recursion doctrine) — the `lnTaylor(0) == 0`
  ## identity is exercised by the test suite.
  body:
    if one(F) + x <= zero(F):
      raise newException(ValueError, "lnTaylor: ln(1+x) undefined for x <= -1")
    var resultVal = x
    var term = x
    var sign = -1

    for n in 2 ..< terms:
      term = term * x
      let nextTerm = term / fromInt(F, n)
      if sign == -1:
        resultVal = resultVal - nextTerm
        sign = 1
      else:
        resultVal = resultVal + nextTerm
        sign = -1

    return resultVal
