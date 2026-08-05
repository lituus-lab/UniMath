# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Taylor/Maclaurin series for `sin`, `cos`, and `atan`, generic over any
## `Field`. Integer factorials/coefficients come from the uniform `fromInt(F, n)`
## construction. `atan` uses the Gregory-Leibniz series (converges for
## `|x| <= 1`); callers range-reduce `|x| > 1` -- the body does NOT reduce, so
## `|x| > 1` diverges slowly.
import contracts
import ../arithmetic

func sinTaylor*[F: Field](x: F, terms: int = 5): F {.contractual.} =
  ## `sin(x) = x - x^3/3! + x^5/5! - ...` for any `Field`.
  ##
  ## No inline `ensure:` (recursion doctrine) — `x == zero(F)` / `result ==
  ## zero(F)` resolve, for `BigFloat`/`Rational`, to the contracted `cmp`
  ## (re-entrant from an ensure); the `sinTaylor(0) == 0` identity is
  ## exercised by the test suite.
  body:
    var resultVal = x
    var term = x
    let x2 = x * x
    var sign = -1

    for n in 1 ..< terms:
      term = term * x2
      let factF = fromInt(F, (2 * n) * (2 * n + 1))
      term = term / factF
      if sign == -1:
        resultVal = resultVal - term
        sign = 1
      else:
        resultVal = resultVal + term
        sign = -1

    return resultVal

func cosTaylor*[F: Field](x: F, terms: int = 5): F {.contractual.} =
  ## `cos(x) = 1 - x^2/2! + x^4/4! - ...` for any `Field`.
  ##
  ## No inline `ensure:` (recursion doctrine); the `cosTaylor(0) == 1`
  ## identity is exercised by the test suite.
  body:
    var resultVal = fromInt(F, 1)
    var term = fromInt(F, 1)
    let x2 = x * x
    var sign = -1

    for n in 1 ..< terms:
      term = term * x2
      let factF = fromInt(F, (2 * n - 1) * (2 * n))
      term = term / factF
      if sign == -1:
        resultVal = resultVal - term
        sign = 1
      else:
        resultVal = resultVal + term
        sign = -1

    return resultVal

func atanTaylor*[F: Field](x: F, terms: int = 10): F {.contractual.} =
  ## `atan(x) = x - x^3/3 + x^5/5 - x^7/7 + ...` (Gregory-Leibniz) for any
  ## `Field`. Converges for `|x| <= 1`; callers range-reduce `|x| > 1` (the body
  ## does not reduce).
  ##
  ## No inline `ensure:` (recursion doctrine); the `atanTaylor(0) == 0`
  ## identity is exercised by the test suite.
  body:
    var resultVal = x
    var term = x
    let x2 = x * x
    for n in 1 ..< terms:
      term = term * x2
      let t = term / fromInt(F, 2 * n + 1)
      if n mod 2 == 1:
        resultVal = resultVal - t
      else:
        resultVal = resultVal + t
    return resultVal
