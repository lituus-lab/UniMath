# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Bessel function of the first kind `J0` via its power series, generic over
## `OrderedField`.
##
## The series is advanced by the term-ratio recurrence
## `term_n = term_{n-1} * (x/2)^2 / n^2`, so the denominator `(n!)^2` is never
## formed as an integer — only the `O(n^2)` factor `n*n` is built as an `int`,
## which fits `int64` up to `n ~ 3.0e9`. No factorial accumulator, no silent
## integer overflow for any realistic `terms`.
##
## The `J0` series is `1 + sum_{n>=1} ...`, every non-constant term carrying a
## factor `(x/2)^(2n)`, so `J0(0) == 1` exactly. That is not asserted inline
## (recursion doctrine) and is exercised by the test suite.
import contracts
import ../arithmetic

func besselJ0*[F: OrderedField](x: F, terms: int = 15): F {.contractual.} =
  ## `J0(x) = sum_{n>=0} (-1)^n (x/2)^(2n) / (n!)^2`, truncated at `terms`.
  ## Advanced by the term-ratio recurrence, so no integer factorial is formed.
  body:
    let xHalf = x / fromInt(F, 2)
    let x2 = xHalf * xHalf

    var resultVal = one(F)
    var term = one(F)

    var sign = -1

    for n in 1 ..< terms:
      term = term * x2
      let n2 = fromInt(F, n * n)
      term = term / n2

      if sign == -1:
        resultVal = resultVal - term
        sign = 1
      else:
        resultVal = resultVal + term
        sign = -1

    return resultVal
