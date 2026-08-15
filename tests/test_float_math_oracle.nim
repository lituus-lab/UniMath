# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## `float_math` transcendental cross-check against the independent MPFR oracle.
## The range-reduced BigFloat result is reduced to float64 by `toFloat64` and
## compared to MPFR's correctly-rounded float64 reference (`mpfrRef`) and its
## 2048-bit exact ulp error (`mpfrErr`): a correctly-rounded candidate reports
## `ulp <= 0.5`, faithful `<= 1`. Only `sin`/`cos`/`exp`/`ln`/`sqrt` are in the
## oracle's `TranscOps`; `tan`/`arctan`/`pow` are covered by the identity tests in
## `test_float_math`. Run with `nimble testOracle` (needs libmpfr; not in the
## default gate).
import std/unittest
import UniMath
import oracles/oracle

const RefPrec = 53 # single rounding to binary64
                   # Faithful bound: the range-reduced series + 256-bit rounding land within 1 ulp
                   # of the correctly-rounded float64. (Correctly rounded is <= 0.5.)
const UlpBound = 1.0

proc bf(x: float64, precision = 256): BigFloat = initBigFloat(x, precision)

proc checkTransc(op: string, cand, x: float64) =
  let refVal = mpfrRef(op, RefPrec, x)
  check cand == refVal # matches the correctly-rounded float64
  let (_, _, ulp) = mpfrErr(op, RefPrec, cand, x)
  check ulp <= UlpBound

suite "float_math vs MPFR — sin/cos":
  test "default budgets are correctly rounded":
    for precision in [256, 320, 384]:
      for x in [0.5, 1.0, 1.5, -0.7]:
        checkTransc("sin", toFloat64(sin(bf(x, precision))), x)
        checkTransc("cos", toFloat64(cos(bf(x, precision))), x)
  test "small arguments are correctly rounded":
    for x in [0.5, 1.0, 1.5, 2.0, 3.0, -0.7, -2.3]:
      checkTransc("sin", toFloat64(sin(bf(x), 40)), x)
      checkTransc("cos", toFloat64(cos(bf(x), 40)), x)
  test "zeros":
    check toFloat64(sin(bf(0.0), 40)) == mpfrRef("sin", RefPrec, 0.0)
    check toFloat64(cos(bf(0.0), 40)) == mpfrRef("cos", RefPrec, 0.0)

suite "float_math vs MPFR — exp/ln":
  test "default exp budget is correctly rounded":
    for x in [0.5, 1.0, 2.0, -3.0]:
      checkTransc("exp", toFloat64(exp(bf(x))), x)
  test "exp":
    for x in [0.5, 1.0, 2.0, 5.0, -3.0, 10.0]:
      checkTransc("exp", toFloat64(exp(bf(x), 40)), x)
  test "ln":
    for x in [0.5, 2.0, 3.0, 10.0, 100.0, 0.1]:
      checkTransc("ln", toFloat64(ln(bf(x), 40)), x)

suite "float_math vs MPFR — sqrt":
  test "sqrt":
    for x in [2.0, 3.0, 4.0, 10.0, 0.25, 144.0]:
      checkTransc("sqrt", toFloat64(sqrt(bf(x))), x)
