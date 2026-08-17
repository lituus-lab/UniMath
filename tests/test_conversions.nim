# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[unittest, math]
import UniMath

suite "conversions — float64 -> Rational (exact)":
  test "toRationalExact: dyadic values and exact round-trip":
    for v in [0.5, 0.25, 3.625, -7.875, 42.0, 0.0]:
      let r = toRationalExact(v)
      check toFloat64(r) == v
    # 0.1 is NOT 1/10: it is the exact value of the nearest double.
    let r01 = toRationalExact(0.1)
    check toFloat64(r01) == 0.1
    check r01.den != 10

  test "toRationalExact: NaN/Inf and overflow -> ValueError":
    expect ValueError: discard toRationalExact(NaN)
    expect ValueError: discard toRationalExact(Inf)
    expect ValueError: discard toRationalExact(5e-300) # denominator >> 2^62

  test "toRationalBig: exact with no exponent limit":
    for v in [0.1, 1e300, -2.5, 0.0]:
      let r = toRationalBig(v)
      check toFloat64(r) == v

  test "toRationalBig: exactness in extreme exponent range (5e-300)":
    let v = 5e-300
    let r = toRationalBig(v)
    let denScaled = initBigInt(r.den.mag shr 996, false)
    let rScaled = initRational(r.num, denScaled)
    check toFloat64(rScaled) == v * pow(2.0, 996.0)

suite "conversions — Fixed <-> Rational/BigFloat":
  test "Fixed -> Rational exact (Q32.32)":
    let f = toFixed[int64, 32](2.5)
    let r = toRational(f)
    check r.num == 5 and r.den == 2
    check toFloat64(r) == 2.5

  test "Fixed -> BigFloat exact":
    let f = toFixed[int64, 32](-3.25)
    let bf = toBigFloat(f, 128)
    check toFloat64(bf) == -3.25

  test "Rational -> Fixed truncated (1/3 in Q32.32)":
    let r = initRational(1'i64, 3'i64)
    let f = toFixed[int64, 32](r)
    check abs(toFloat64(f) - 1.0 / 3.0) < pow(2.0, -31.0)
    check toFloat64(f) <= 1.0 / 3.0 # truncation toward zero

  test "Rational -> Fixed: overflow detected":
    let r = initRational(high(int64) div 2, 1'i64)
    expect ValueError: discard toFixed[int64, 32](r)

suite "conversions — Rational -> BigFloat directed":
  test "1/3: rmUp/rmDown bounds bracket the value":
    let r = initRational(1'i64, 3'i64)
    let up = toBigFloat(r, 64, rmUp)
    let down = toBigFloat(r, 64, rmDown)
    check toFloat64(down) <= 1.0 / 3.0
    check toFloat64(up) >= 1.0 / 3.0
    check toFloat64(subRounded(up, down, 64, rmUp)) > 0.0

  test "dyadic value: exact conversion whatever the mode":
    let r = initRational(5'i64, 8'i64)
    for mode in [rmNearest, rmTrunc, rmUp, rmDown]:
      check toFloat64(toBigFloat(r, 64, mode)) == 0.625

suite "conversions — to BigInt (truncation)":
  test "BigFloat -> BigInt":
    check toBigInt(initBigFloat(42.75, 64)) == initBigInt(42)
    check toBigInt(initBigFloat(-42.75, 64)) == initBigInt(-42)
    check toBigInt(initBigFloat(0.0, 64)) == initBigInt(0)
    check toBigInt(initBigFloat(-0.5, 64)) == initBigInt(0)

  test "Rational -> BigInt":
    check toBigInt(initRational(7'i64, 2'i64)) == initBigInt(3)
    check toBigInt(initRational(-7'i64, 2'i64)) == initBigInt(-3)

suite "conversions — to Interval (enclosures)":
  test "Rational -> Interval contains the value":
    let r = initRational(1'i64, 3'i64)
    let i = toInterval(r)
    check contains(i, 1.0 / 3.0)
    check width(i) > 0.0

  test "BigFloat -> Interval contains the value":
    let bf = initBigFloat(2.5, 128)
    check contains(toInterval(bf), 2.5)

  test "Fixed -> Interval contains the value":
    let f = toFixed[int64, 32](1.5)
    check contains(toInterval(f), 1.5)

  test "BigInt -> Interval contains the float rounding":
    let b = initBigInt(123456789)
    check contains(toInterval(b), 123456789.0)

suite "conversions — BigFloat -> Fixed":
  test "exact value on the Q32.32 grid":
    let bf = initBigFloat(2.5, 128)
    let f = toFixed[int64, 32](bf)
    check toFloat64(f) == 2.5

  test "overflow detected":
    let bf = initBigFloat(1e18, 128)
    expect ValueError: discard toFixed[int64, 32](bf)

suite "conversions — BigFloat -> float64, rounding and the subnormal band":
  # The round window and sticky tail are read from the mantissa's limbs. The
  # subnormal branch is the one with no other coverage: it single-rounds the
  # full mantissa to the 2^-1074 quantum and bit-packs the result, so a wrong
  # sticky bit there produces a silently wrong denormal rather than a crash.

  test "round-trips every normal boundary exactly":
    # 1.797...e308 is the largest normal, 2.225...e-308 the smallest, and
    # 4.940...e-324 the smallest subnormal (the 2^-1074 quantum itself).
    const boundaries = [1.0, 0.5, 0.1, -3.25, 2.0, 1e308, -1e308,
      1.7976931348623157e308, 2.2250738585072014e-308, 4.9406564584124654e-324]
    for v in boundaries:
      check toFloat64(initBigFloat(v, 256)) == v

  test "round-trips inside the subnormal band":
    # Powers of two spanning the band, plus values with bits low in the
    # mantissa so the sticky path is actually exercised.
    for k in 1023 .. 1074:
      let v = pow(2.0, -float64(k))
      if v == 0.0: continue
      check toFloat64(initBigFloat(v, 256)) == v
    for v in [1e-310, 5e-320, 3e-322, 1.5e-323]:
      check toFloat64(initBigFloat(v, 256)) == v

  test "largest subnormal and smallest normal are distinguished":
    let maxSub = 2.2250738585072009e-308
    let minNorm = 2.2250738585072014e-308
    check maxSub != minNorm
    check toFloat64(initBigFloat(maxSub, 256)) == maxSub
    check toFloat64(initBigFloat(minNorm, 256)) == minNorm

  test "rounds to nearest, ties to even, below the float64 ulp":
    let one = initBigFloat(1.0, 256)
    # ulp(1.0) = 2^-52; half an ulp is a tie and must go to the even mantissa.
    let halfUlp = initBigFloat(pow(2.0, -53.0), 256)
    check toFloat64(addRounded(one, halfUlp, 256, rmNearest)) == 1.0
    # Three quarters of an ulp is above the tie: rounds up.
    let threeQuarter = initBigFloat(3.0 * pow(2.0, -54.0), 256)
    check toFloat64(addRounded(one, threeQuarter, 256, rmNearest)) ==
          1.0 + pow(2.0, -52.0)
    # A bit far below the ulp only sets sticky; nearest still returns 1.0.
    let tiny = initBigFloat(pow(2.0, -200.0), 256)
    check toFloat64(addRounded(one, tiny, 256, rmNearest)) == 1.0

  test "sign is carried on both branches":
    for v in [-1.0, -1e-310, -4.9406564584124654e-324]:
      let got = toFloat64(initBigFloat(v, 256))
      check got == v
      check signbit(got)

  test "out of range saturates rather than wrapping":
    var big = initBigFloat(1.0, 256)
    big.exponent += 2000
    check toFloat64(big) == Inf
    var small = initBigFloat(1.0, 256)
    small.exponent -= 2000
    check toFloat64(small) == 0.0

proc powBF(k: int): BigFloat =
  ## 2^-k as a 256-bit BigFloat, reachable past the float64 underflow.
  result = initBigFloat(1.0, 256)
  result.exponent -= int64(k)

const quantum = 4.9406564584124654e-324 # 2^-1074, the subnormal ulp

suite "conversions — BigFloat -> float64, the subnormal sticky bit":
  # Values built from an exact float64 have no bits below the 2^-1074 quantum,
  # so their sticky bit is always zero and a broken sticky path still passes.
  # These build values BETWEEN two subnormals by moving the exponent directly,
  # which is the only way to make the branch decide anything.

  test "guard set and tail non-empty rounds the even quantum up":
    # k = 2 (even), plus half a quantum, plus a bit far below it.
    # nearest is halfway-away only when the tail is empty; here the tail is
    # non-empty, so 2.5+ must go to 3 rather than stay at 2.
    let v = addRounded(addRounded(powBF(1073), powBF(1075), 256, rmNearest),
                       powBF(1080), 256, rmNearest)
    check toFloat64(v) == 3.0 * quantum

  test "guard set with an empty tail ties to even":
    # Exactly k = 2.5: a true tie, and 2 is the even neighbour.
    let v = addRounded(powBF(1073), powBF(1075), 256, rmNearest)
    check toFloat64(v) == 2.0 * quantum
    # Exactly k = 3.5 ties up to 4, the even neighbour on that side.
    let w = addRounded(addRounded(powBF(1073), powBF(1074), 256, rmNearest),
                       powBF(1075), 256, rmNearest)
    check toFloat64(w) == 4.0 * quantum

  test "a tail alone, with the guard clear, rounds down":
    let v = addRounded(powBF(1073), powBF(1080), 256, rmNearest)
    check toFloat64(v) == 2.0 * quantum

  test "rounding up out of the subnormal band reaches the smallest normal":
    # k = 2^52 - 0.5 + tail rounds to 2^52, which is the smallest normal.
    let minNormal = 2.2250738585072014e-308
    let v = addRounded(subRounded(powBF(1022), powBF(1075), 256, rmNearest),
                       powBF(1080), 256, rmNearest)
    check toFloat64(v) == minNormal

  test "below half the quantum rounds to zero, keeping the sign":
    let v = powBF(1080)
    check toFloat64(v) == 0.0
    var neg = powBF(1080)
    neg.sign = true
    check toFloat64(neg) == 0.0
    check signbit(toFloat64(neg))
