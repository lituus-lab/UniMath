# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import contracts
import UniMath

const P = DefaultPrecision

suite "BigFloat construction":
  test "from float64 round-trips":
    check toFloat64(initBigFloat(1.5, 64)) == 1.5
    check toFloat64(initBigFloat(-0.125, 64)) == -0.125
    check toFloat64(initBigFloat(0.0)) == 0.0
  test "from BigInt preserves value and sign":
    let a = fromBigInt(initBigInt(-12), P)
    check a.sign == true
    let b = fromBigInt(initBigInt(0), P)
    check b.isZero
  test "Inf and NaN raise":
    # The ensure fails on the default (zero) result, so debug raises
    # PostConditionDefect and release raises ValueError — both are Exceptions.
    expect(Exception):
      discard initBigFloat(Inf)
    expect(Exception):
      discard initBigFloat(-Inf)
    expect(Exception):
      discard initBigFloat(NaN)

suite "BigFloat arithmetic":
  test "add sub negate":
    let a = initBigFloat(10.0, 64)
    let b = initBigFloat(3.0, 64)
    check toFloat64(a + b) == 13.0
    check toFloat64(a - b) == 7.0
    check toFloat64(-a) == -10.0
  test "mul and div":
    let a = initBigFloat(10.0, 64)
    let b = initBigFloat(3.0, 64)
    check toFloat64(a * b) == 30.0
    check abs(toFloat64(a / b) - 3.3333333333333335) < 1e-12
  test "zero propagation and sign rule":
    let z = BigFloat(mantissa: initBigUInt(0'u64))
    let a = initBigFloat(2.5, P)
    let b = initBigFloat(-3.0, P)
    check (z * a).isZero and (a * z).isZero
    let p = a * b
    check p.sign == true # (+) * (-) = (-)
    check bitLength(p.mantissa) == P # normalized
  test "addition cancellation yields zero":
    let a = initBigFloat(1.5, P)
    check (a - a).isZero
    check (a + a).isZero == false
    check bitLength((a + a).mantissa) == P
  test "abs is non-negative and preserves zero-ness":
    let z = BigFloat(mantissa: initBigUInt(0'u64))
    let a = initBigFloat(-4.0, P)
    check abs(a).sign == false
    check abs(a).isZero == false
    check abs(z).isZero

suite "BigFloat comparison":
  test "cmp trichotomy and antisymmetry":
    let a = initBigFloat(1.0, P)
    let b = initBigFloat(2.0, P)
    let c = initBigFloat(1.0, P)
    check cmp(a, b) == -1
    check cmp(b, a) == 1
    check cmp(a, c) == 0
    check cmp(a, b) == -cmp(b, a) # antisymmetry (not in the contract)
  test "operators":
    let a = initBigFloat(3.0, P)
    let b = initBigFloat(5.0, P)
    check (a < b) and (b > a) and (a <= a) and (b >= a) and (a == a) and (a != b)
  test "mixed precision compares by MSB position":
    let hi = initBigFloat(1.0, 256)
    let lo = initBigFloat(1.0, 128)
    check cmp(hi, lo) == 0 # both exactly 1.0 despite diff precision

suite "BigFloat directed rounding":
  test "rmUp and rmDown bracket the nearest quotient":
    let one = initBigFloat(1.0, P)
    let three = initBigFloat(3.0, P)
    let near = divRounded(one, three, P, rmNearest)
    let up = divRounded(one, three, P, rmUp)
    let down = divRounded(one, three, P, rmDown)
    check cmp(down, near) <= 0
    check cmp(up, near) >= 0
    check cmp(down, up) <= 0

suite "BigFloat division at precisions that are not a multiple of a limb":
  # divRounded's fast path takes a divisor nonzero only in its top limb (the
  # Taylor denominator). At 256 bits that limb is always left-aligned; these
  # precisions are not multiples of a limb, where it is not.

  test "small integer divisors, precisions straddling the limb boundary":
    for precision in [24, 53, 60, 64, 65, 100, 128, 191, 192, 221, 255, 256]:
      let one = initBigFloat(1.0, precision)
      for d in [1, 2, 3, 5, 6, 7, 10, 24, 720, 40320]:
        let den = fromBigInt(initBigInt(d), precision)
        let q = divRounded(one, den, precision, rmNearest)
        # q * d must recover 1 to within the working precision.
        let back = mulRounded(q, den, precision, rmNearest)
        let err = abs(toFloat64(back) - 1.0)
        if err > 1e-12:
          checkpoint "precision = " & $precision & "  d = " & $d &
                     "  q = " & $toFloat64(q)
          check err <= 1e-12

  test "the quotient matches a full-width division rounded down":
    # Reference outside the fast path: divide at 256 bits, compare leading bits.
    for precision in [100, 191, 221, 255]:
      let d = 6
      let qNarrow = divRounded(initBigFloat(1.0, precision),
                               fromBigInt(initBigInt(d), precision),
                               precision, rmNearest)
      let qWide = divRounded(initBigFloat(1.0, 256),
                             fromBigInt(initBigInt(d), 256), 256, rmNearest)
      check abs(toFloat64(qNarrow) - toFloat64(qWide)) < 1e-15

suite "BigFloat toFloat64 range":
  test "subnormal: smallest positive 2^-1074":
    var s = fromBigInt(initBigInt(1), P)
    s.exponent = -1074 - (P - 1) # value = 1 * 2^-1074
    check toFloat64(s) == 5e-324
  test "underflow to zero (ties-to-even)":
    var t = fromBigInt(initBigInt(1), P)
    t.exponent = -1075 - (P - 1) # 2^-1075 rounds to 0
    check toFloat64(t) == 0.0
    var u = fromBigInt(initBigInt(1), P)
    u.exponent = -1077 - (P - 1) # below the underflow short-circuit
    check toFloat64(u) == 0.0
  test "overflow to infinity":
    var big = fromBigInt(initBigInt(1), P)
    big.exponent = 1024 - (P - 1) # value = 2^1024
    check toFloat64(big) == Inf
    big.sign = true
    check toFloat64(big) == -Inf
  test "large range: 2^2048 stays finite in BigFloat":
    var a = initBigFloat(2.0, 128)
    for _ in 1 .. 11: # square 2.0 eleven times -> 2^2048
      a = a * a
    check a.exponent > 1000

suite "BigFloat division by zero":
  test "raises DivByZeroDefect (or its debug mask)":
    let a = initBigFloat(7.0, P)
    let z = BigFloat(mantissa: initBigUInt(0'u64))
    expect(Defect):
      discard a / z

suite "BigFloat concept construction":
  test "zero and one":
    check toFloat64(zero(BigFloat)) == 0.0
    check toFloat64(one(BigFloat)) == 1.0
  test "fromInt and fromFloat typedesc":
    check toFloat64(fromInt(BigFloat, 5)) == 5.0
    check toFloat64(fromFloat(BigFloat, 2.5)) == 2.5
  test "Field concept accepts BigFloat":
    proc dbl[T: Field](x: T): T = x + x
    check toFloat64(dbl(initBigFloat(3.0, 64))) == 6.0

when not defined(release):
  suite "BigFloat contract machinery is active in debug":
    proc deliberatelyBroken(): int {.contractual.} =
      ensure:
        result == 1
      body:
        0
    proc honest(): int {.contractual.} =
      ensure:
        result == 1
      body:
        1
    test "broken postcondition raises PostConditionDefect":
      var caught = false
      try:
        discard deliberatelyBroken()
      except PostConditionDefect:
        caught = true
      check caught
    test "honoured postcondition returns normally":
      check honest() == 1
