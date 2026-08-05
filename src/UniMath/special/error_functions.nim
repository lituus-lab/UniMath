# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Error function `erf` via its Taylor series, generic over `OrderedField`.
## Integer coefficients use the uniform `fromInt(F, n)` overload. The
## transcendental witnesses `piConst` (the value of pi in `F`) and `sqrtFunc`
## (a square-root in `F`) are injected: `erf` needs `sqrt(pi)`, which is not
## constructible from `int` alone (a `Transcendental` concept is deferred).
##
## The series is advanced by the term-ratio recurrence
## `term_n = term_{n-1} * (-x^2) * (2n-1) / (n*(2n+1))`, whose only integer
## factors are `2n-1` and `n*(2n+1) = O(n^2)` — both fit `int64` up to
## `terms ~ 2.1e9`. This avoids the integer-factorial accumulator that
## overflowed `int64` at `terms >= 21` (21! ~ 5.1e19) and silently wrapped under
## release. The recurrence telescopes the factorial exactly, matching the old
## sum term-for-term.
##
## `erf` is entire (domain is all of `F`), so there is no body `raise`. The
## truncated polynomial has no constant term, so `erf(0) == 0` exactly; that is
## not asserted inline (recursion doctrine) and is exercised by the test suite.
import contracts
import ../arithmetic

func erfTaylor*[F: OrderedField](x: F, terms: int = 15, piConst: F,
                                 sqrtFunc: proc(v: F): F {.noSideEffect.}): F
                                 {.contractual.} =
  ## `erf(x) = (2/sqrt(pi)) * sum_{n>=0} (-1)^n x^(2n+1) / (n!*(2n+1))`,
  ## truncated at `terms` (default 15, accurate for `|x| <= 2..3`; for larger
  ## `|x|` use a rational/continued-fraction `erf` — deferred). Overflow-free
  ## for any realistic `terms` via the term-ratio recurrence.
  body:
    let sqrtPi = sqrtFunc(piConst)
    let coeff = fromInt(F, 2) / sqrtPi

    var resultVal = x
    var term = x
    let x2 = x * x

    var addNext = false

    for n in 1 ..< terms:
      term = term * x2 * fromInt(F, 2 * n - 1) / fromInt(F, n * (2 * n + 1))
      if addNext:
        resultVal = resultVal + term
        addNext = false
      else:
        resultVal = resultVal - term
        addNext = true

    return coeff * resultVal
