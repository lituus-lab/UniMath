# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Exponential tests: Taylor `exp`/`ln(1+x)` and the generic `ln(z)`, over
## float64 and `BigFloat`. The Taylor series converge slowly far from the
## expansion point, so the float64 checks stay in the well-conditioned range.
import std/[unittest, math]
import UniMath

suite "expTaylor":
  test "float64 near 0":
    check abs(expTaylor(0.0) - 1.0) < 1e-12
    check abs(expTaylor(1.0) - E) < 1e-6
    check abs(expTaylor(-1.0) - 1.0 / E) < 1e-6
  test "BigFloat":
    let p = 128
    check abs(toFloat64(expTaylor(initBigFloat(0.0, p))) - 1.0) < 1e-20
    check abs(toFloat64(expTaylor(initBigFloat(1.0, p))) - E) < 1e-10

suite "lnTaylor — ln(1+x)":
  test "float64 near 0":
    check abs(lnTaylor(0.0) - 0.0) < 1e-12
    # 15-term alternating series at |x|=0.5 converges to ~1e-5.
    check abs(lnTaylor(0.5) - ln(1.5)) < 1e-4
    check abs(lnTaylor(-0.5) - ln(0.5)) < 1e-4
  test "domain error x <= -1":
    expect ValueError:
      discard lnTaylor(-1.0)
    expect ValueError:
      discard lnTaylor(-2.0)

suite "lnGeneric — ln(z) for any positive z":
  test "float64":
    check abs(lnGeneric(1.0) - 0.0) < 1e-12
    check abs(lnGeneric(E) - 1.0) < 1e-6
    check abs(lnGeneric(2.0) - ln(2.0)) < 1e-6
    check abs(lnGeneric(0.5) - ln(0.5)) < 1e-6
  test "BigFloat":
    let p = 128
    check abs(toFloat64(lnGeneric(initBigFloat(1.0, p))) - 0.0) < 1e-20
    check abs(toFloat64(lnGeneric(initBigFloat(2.0, p))) - ln(2.0)) < 1e-10
  test "domain error z <= 0":
    expect ValueError:
      discard lnGeneric(0.0)
    expect ValueError:
      discard lnGeneric(-1.0)

suite "ln1pGeneric":
  test "matches ln(1+x) where both are well conditioned":
    check abs(ln1pGeneric(0.0) - 0.0) < 1e-18
    check abs(ln1pGeneric(1.0) - ln(2.0)) < 1e-15
    check abs(ln1pGeneric(0.5) - ln(1.5)) < 1e-15
    check abs(ln1pGeneric(-0.5) - ln(0.5)) < 1e-15
  test "keeps full relative accuracy where 1 + x rounds to 1":
    # ln(1+x) ~ x - x^2/2 for a small x. Forming 1 + x first rounds it to 1
    # once x drops below the epsilon, and loses a digit per power of two
    # before that; the series in x never forms the sum.
    for k in 8 .. 18:
      let x = pow(10.0, -float64(k))
      let want = x - x * x / 2.0
      # Two ulp of the result, not of 1: the point is that the answer keeps
      # its own scale instead of being measured against the discarded 1.
      check abs(ln1pGeneric(x) - want) <= 4.5e-16 * abs(want)
  test "the naive form is the one that fails":
    # Guards the reason this proc exists: below the epsilon, 1 + x IS 1.
    let x = 1e-18
    check 1.0 + x == 1.0
    check lnGeneric(1.0 + x) == 0.0
    check ln1pGeneric(x) > 0.0
  test "BigFloat carries the same identity":
    let p = 128
    check abs(toFloat64(ln1pGeneric(initBigFloat(1.0, p))) - ln(2.0)) < 1e-10
  test "domain error 1 + x <= 0":
    expect ValueError:
      discard ln1pGeneric(-1.0)
    expect ValueError:
      discard ln1pGeneric(-2.0)
