# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import std/strutils
import UniMath

suite "Fixed construction":
  test "from integer shifts by FracBits":
    check toFixed[int32, 16](5).data == int32(5 shl 16)
    check toFixed[int64, 32](7).data == 7'i64 shl 32
  test "from float scales and truncates":
    let f = toFixed[int32, 16](3.75)
    check f.data == int32(245760) # 3.75 * 2^16
    check toFloat64(f) == 3.75
  test "toInt and fracPart":
    let a = toFixed[int64, 32](7)
    check toInt(a) == int64(7)
    check fracPart(a) == int64(0)
    let b = toFixed[int64, 32](3.75)
    check toInt(b) == int64(3)
    check fracPart(b) == int64(0.75 * float(1'i64 shl 32))
  test "toInt floors and fracPart stays non-negative, and they reconstruct":
    # toFixed truncates toward zero, toInt floors: the parts of a negative
    # value are -4 and +0.75, which still sum back to -3.25.
    let c = toFixed[int64, 32](-3.25)
    check toInt(c) == int64(-4)
    check fracPart(c) == int64(0.75 * float(1'i64 shl 32))
    check toFloat64(initFixed[int64, 32](
      (toInt(c) shl 32) + fracPart(c))) == -3.25
  test "predefined aliases":
    check toFloat64(toFixed[int32, 16](2)) == 2.0 # Fixed32
    check toFloat64(toFixed[int64, 32](2)) == 2.0 # Fixed64
    check toFloat64(GeoFPN(toFixed[int64, 32](1))) == 1.0
    check toFloat64(CartesianFPN(toFixed[int64, 16](1))) == 1.0
    check toFloat64(GeometryFPN(toFixed[int64, 32](1))) == 1.0
  test "overflow raises in all modes":
    expect(Defect):
      discard toFixed[int32, 16](high(int32)) # shifted value out of int32
    expect(Defect):
      discard toFixed[int32, 16](1.0e20) # scaled value out of int32

suite "Fixed arithmetic":
  test "add sub negate":
    let a = toFixed[int64, 32](3)
    let b = toFixed[int64, 32](2)
    check toFloat64(a + b) == 5.0
    check toFloat64(a - b) == 1.0
    check toFloat64(-a) == -3.0
  test "add sub negate overflow raises":
    # Same-width +/- and unary - now range-check (no silent wrap), consistent
    # with the widening */ which use a BigInt intermediate.
    let big = toFixed[int32, 16](32767) # data just under high(int32)
    expect(Defect):
      discard big + big # data sum exceeds int32
    expect(Defect):
      discard toFixed[int32, 16](-32767) - big # data difference underflows int32
    let negBound = toFixed[int32, 16](-32768) # data == low(int32)
    expect(Defect):
      discard -negBound # negating low(int32) overflows
  test "mul is exact via BigInt intermediate":
    let a = toFixed[int64, 32](3)
    let b = toFixed[int64, 32](4)
    check toFloat64(a * b) == 12.0
    check (a * b).data == int64(12) shl 32
  test "mul of large fixed-precision values overflows":
    let a = toFixed[int32, 16](1000)
    let b = toFixed[int32, 16](1000)
    expect(Defect):
      discard a * b # 1e6 real, data 1e6 shl 16 exceeds int32
  test "div truncates":
    let a = toFixed[int64, 32](7)
    let b = toFixed[int64, 32](2)
    check toFloat64(a / b) == 3.5
    let c = toFixed[int64, 32](1)
    let d = toFixed[int64, 32](3)
    check abs(toFloat64(c / d) - 1.0 / 3.0) < 1e-9 # 1/3 in Q32.32 (truncated)
  test "div by zero raises":
    let a = toFixed[int64, 32](7)
    let z = toFixed[int64, 32](0)
    expect(Defect):
      discard a / z

suite "Fixed comparison":
  test "cmp and operators":
    let a = toFixed[int64, 32](3)
    let b = toFixed[int64, 32](5)
    check cmp(a, b) == -1
    check cmp(b, a) == 1
    check cmp(a, a) == 0
    check (a < b) and (b > a) and (a <= a) and (b >= a) and (a == a) and (a != b)

suite "Fixed utilities":
  test "floor ceil round":
    let a = toFixed[int64, 32](3.75)
    check toFloat64(floor(a)) == 3.0
    check toFloat64(ceil(a)) == 4.0
    check toFloat64(round(a)) == 4.0
    let b = toFixed[int64, 32](3.4)
    check toFloat64(round(b)) == 3.0
    let c = toFixed[int64, 32](3.0)
    check toFloat64(ceil(c)) == 3.0
  test "clamp":
    let lo = toFixed[int64, 32](0)
    let hi = toFixed[int64, 32](10)
    check toFloat64(clamp(toFixed[int64, 32](5), lo, hi)) == 5.0
    check toFloat64(clamp(toFixed[int64, 32](15), lo, hi)) == 10.0
    check toFloat64(clamp(toFixed[int64, 32](-3), lo, hi)) == 0.0
  test "lerp":
    let a = toFixed[int64, 32](0)
    let b = toFixed[int64, 32](10)
    let t = toFixed[int64, 32](0.5)
    check toFloat64(lerp(a, b, t)) == 5.0
  test "floorMod":
    check toFloat64(floorMod(toFixed[int64, 32](7), toFixed[int64, 32](3))) == 1.0
    check toFloat64(floorMod(toFixed[int64, 32](-7), toFixed[int64, 32](3))) == 2.0
  test "floorMod by zero raises":
    expect(Defect):
      discard floorMod(toFixed[int64, 32](7), toFixed[int64, 32](0))
  test "abs and sign":
    check toFloat64(abs(toFixed[int64, 32](-5))) == 5.0
    check sign(toFixed[int64, 32](-5)) == -1
    check sign(toFixed[int64, 32](0)) == 0
    check sign(toFixed[int64, 32](5)) == 1

suite "Fixed concept construction":
  test "zero and one":
    check toFloat64(zero(Fixed64)) == 0.0
    check toFloat64(one(Fixed64)) == 1.0
  test "fromInt and fromFloat typedesc":
    check toFloat64(fromInt(Fixed64, 5)) == 5.0
    check toFloat64(fromFloat(Fixed64, 2.5)) == 2.5
  test "Field concept accepts Fixed":
    proc dbl[T: Field](x: T): T = x + x
    check toFloat64(dbl(toFixed[int64, 32](3))) == 6.0

suite "Fixed[BigInt] exact arithmetic":
  test "large product does not overflow":
    let a = toFixed[BigInt, 16](100) # int -> BigInt storage via toBig
    let b = toFixed[BigInt, 16](7)
    let p = a * b
    # real value 700, data = 700 shl 16
    check toDecimal(p.data shr Natural(16)) == "700"
  test "huge product stays exact":
    var n = initBigInt(1)
    for _ in 1 .. 20: n = n * initBigInt(10) # 10^20 (exceeds int64)
    let a = initFixed[BigInt, 16](n shl Natural(16))
    let b = initFixed[BigInt, 16](n shl Natural(16))
    let p = a * b
    check toDecimal(p.data shr Natural(16)) == "1" & repeat('0', 40)
