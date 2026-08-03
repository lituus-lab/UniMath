# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## BigFloat arithmetic cross-check against the independent MPFR oracle. For
## each binary op the Nim BigFloat result is converted to float64 and compared
## to MPFR's correctly-rounded float64 reference (bin) and its 2048-bit exact
## error (berr): a correctly-rounded candidate reports ulp_err <= 0.5. Run with
## `nimble testOracle` (needs libmpfr; not in the default gate).
import std/[unittest, random]
import UniMath
import oracles/oracle

# Precision used for the float64 reference: 53 is a single rounding (the value
# is already binary64), inside the safe band of `checkPrec`.
const RefPrec = 53

suite "BigFloat vs MPFR — arithmetic":
  test "add/sub/mul/div match the correctly-rounded float64":
    let cases: seq[(string, float64, float64)] = @[
      ("add", 10.0, 3.0), ("sub", 10.0, 3.0), ("mul", 10.0, 3.0),
      ("div", 10.0, 3.0), ("add", -0.125, 1.5), ("mul", 1.5, -2.25),
      ("div", 1.0, 7.0), ("sub", 1e-8, 1.0),
    ]
    for (op, a, b) in cases:
      let ba = initBigFloat(a, 64)
      let bb = initBigFloat(b, 64)
      let cand =
        case op
        of "add": toFloat64(ba + bb)
        of "sub": toFloat64(ba - bb)
        of "mul": toFloat64(ba * bb)
        of "div": toFloat64(ba / bb)
        else: 0.0
      check cand == mpfrBinRef(op, RefPrec, a, b)
      let (_, _, ulp) = mpfrBinErr(op, RefPrec, cand, a, b)
      check ulp <= 0.5 # correctly rounded

  test "randomized mul/div are correctly rounded":
    randomize(20260722)
    for _ in 0 ..< 200:
      let a = rand(-1e6 .. 1e6)
      let b = rand(-1e6 .. 1e6)
      if b == 0.0: continue
      let ba = initBigFloat(a, 64)
      let bb = initBigFloat(b, 64)
      let mul = toFloat64(ba * bb)
      check mul == mpfrBinRef("mul", RefPrec, a, b)
      let dv = toFloat64(ba / bb)
      check dv == mpfrBinRef("div", RefPrec, a, b)
