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
