# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## How much of a 256-bit transcendental result is actually correct?
##
## THIS FILLS A HOLE THE ORACLE SUITE CANNOT COVER. `test_float_math_oracle`
## compares `toFloat64(...)` against a 2048-bit MPFR reference, so it verifies
## about 53 bits of a 256-bit answer. Everything an argument reduction or a
## series rearrangement does to bits 54..256 is invisible to it.
##
## That is not hypothetical. `exp` was short by roughly `k` bits -- 16 of 256 at
## `exp(700)` -- for as long as it squared its reduced argument back at the bare
## working precision, and every test in the repository stayed green. These bounds
## are what makes that visible, and what now holds the guard in place.
##
## The reference is the same computation at a higher precision. Its own error is
## around `2^-512` against the `2^-256` being measured, so it stands in for the
## exact value. That makes these CHARACTERISATION bounds, not proofs of
## accuracy: they record what the implementation does today so a change cannot
## quietly make it worse. Tightening them when an algorithm improves is
## expected; loosening one is a decision that needs saying out loud.

import std/[unittest, strutils]
import UniMath

const
  P = 256    ## the precision under test
  RefP = 512 ## the reference precision

func ulpErrLog2(cand, reference: BigFloat): int =
  ## `log2` of `|cand - reference|` in ulps of `cand`, or `low(int)` when the
  ## two agree exactly. A result of `n` means about `2^n` ulps.
  let d = subRounded(cand, reference, RefP + 64, rmNearest)
  if d.isZero: return low(int)
  let dTop = d.exponent + int64(bitLength(d.mantissa)) - 1
  # For a mantissa normalised to `precision` bits, ulp(cand) = 2^cand.exponent.
  int(dTop - cand.exponent)

template checkUlps(name: string, arg: float64, bound: int, call: untyped) =
  ## `call` is evaluated with `x` bound to the argument at both precisions.
  block:
    let x {.inject.} = initBigFloat(arg, P)
    let cand = call
    let xRef = initBigFloat(arg, RefP)
    let reference = block:
      let x {.inject.} = xRef
      call
    let e = ulpErrLog2(cand, reference)
    if e > bound:
      checkpoint name & "(" & formatFloat(arg, ffDefault, 6) & "): 2^" & $e &
                 " ulps, bound 2^" & $bound
    check e <= bound

suite "float_math precision at the full working width — exp":
  # exp squares its reduced argument back k times and each squaring doubles the
  # relative error, so the chain is run at `precision + k + expGuardBits` and
  # rounded once at the end. These bounds are what that buys: before the guard,
  # the same arguments measured 2^10 (exp(1)) to 2^16 ulps (exp(700)) -- ten to
  # sixteen bits of a 256-bit result, invisible to a float64 oracle.
  #
  # 2^2 leaves a 16x margin over the worst measured value (2^-2). A failure here
  # means the guard stopped covering the chain, not that a bound was too tight.
  test "small arguments":
    checkUlps("exp", 1e-8, 2): exp(x)
    checkUlps("exp", 0.001, 2): exp(x)
    checkUlps("exp", 0.5, 2): exp(x)

  test "moderate arguments":
    checkUlps("exp", 1.0, 2): exp(x)
    checkUlps("exp", 2.0, 2): exp(x)
    checkUlps("exp", -3.0, 2): exp(x)

  test "extreme arguments, where the squaring chain is deepest":
    checkUlps("exp", 10.0, 2): exp(x)
    checkUlps("exp", 50.0, 2): exp(x)
    checkUlps("exp", 700.0, 2): exp(x)
    checkUlps("exp", -700.0, 2): exp(x)

suite "float_math precision at the full working width — sin and cos":
  # sin/cos fold into [0, pi/4] and then run the series directly, with no
  # squaring chain, so they hold far more bits than exp does.
  test "sin over the reduction octants":
    checkUlps("sin", 0.5, 6): sin(x)
    checkUlps("sin", 1.0, 6): sin(x)
    checkUlps("sin", 2.0, 6): sin(x)
    checkUlps("sin", 3.0, 8): sin(x)
    checkUlps("sin", 10.0, 10): sin(x)

  test "cos over the reduction octants":
    checkUlps("cos", 0.5, 6): cos(x)
    checkUlps("cos", 1.0, 6): cos(x)
    checkUlps("cos", 2.0, 8): cos(x)
    checkUlps("cos", 10.0, 10): cos(x)

suite "float_math precision at the full working width — ln, sqrt, arctan":
  test "ln over the mantissa-halving threshold":
    checkUlps("ln", 2.0, 6): ln(x)
    checkUlps("ln", 3.0, 6): ln(x)
    checkUlps("ln", 0.1, 6): ln(x)
    checkUlps("ln", 100.0, 8): ln(x)
    checkUlps("ln", 1e100, 10): ln(x)

  test "sqrt is a self-correcting Newton and should be near-exact":
    checkUlps("sqrt", 2.0, 2): sqrt(x)
    checkUlps("sqrt", 3.0, 2): sqrt(x)
    checkUlps("sqrt", 0.25, 2): sqrt(x)
    checkUlps("sqrt", 1e100, 2): sqrt(x)

  test "arctan over the tan(pi/8) reduction":
    checkUlps("arctan", 0.5, 6): arctan(x)
    checkUlps("arctan", 1.0, 6): arctan(x)
    checkUlps("arctan", 5.0, 8): arctan(x)

suite "float_math precision — the bounds can fail":
  test "a deliberately wrong result trips the comparison":
    # A detector that cannot fail is indistinguishable from a disabled one.
    let x = initBigFloat(1.0, P)
    let good = exp(x)
    # Perturb the last bit of the mantissa: one ulp, so log2 is 0.
    var bad = good
    bad.mantissa.limbs[0] = bad.mantissa.limbs[0] xor 1'u64
    check ulpErrLog2(bad, good) == 0
    # Perturb bit 40: about 2^40 ulps, far past every bound above.
    var worse = good
    worse.mantissa.limbs[0] = worse.mantissa.limbs[0] xor (1'u64 shl 40)
    check ulpErrLog2(worse, good) == 40
