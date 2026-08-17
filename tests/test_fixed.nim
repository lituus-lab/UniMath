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

suite "Fixed machine-storage multiply matches the BigInt route":
  # `*` takes a direct 64x64 -> 128 path for machine signed storage and keeps
  # the BigInt intermediate for BigInt storage. The two must be
  # indistinguishable, including where they are easiest to get wrong: the floor
  # rounding of a negative product (BigInt's `shr` is arithmetic, so a dropped
  # bit rounds AWAY from zero) and every OverflowDefect boundary.

  proc bigRoute(ad, bd: int64, fracBits: int): tuple[value: int64, fits: bool] =
    ## The generic overload's computation, spelled out so the test does not
    ## depend on which overload the compiler selects for a given storage type.
    let big = (toBigInt(ad) * toBigInt(bd)) shr Natural(fracBits)
    try:
      (big.toInt64(), true)
    except Defect, CatchableError:
      (0'i64, false)

  const edges = [0'i64, 1, -1, 2, -2, 3, -3, 7, -7, 255, -255,
                 high(int64), low(int64), high(int64) - 1, low(int64) + 1,
                 1'i64 shl 31, -(1'i64 shl 31), 1'i64 shl 32, -(1'i64 shl 32),
                 1'i64 shl 62, -(1'i64 shl 62),
                 0x5555555555555555'i64, -0x5555555555555555'i64]

  proc probe[T; FracBits: static[int]](ad, bd: int64, kind: string) =
    ## Compare the two routes for one storage type at one scale.
    if ad < int64(low(T)) or ad > int64(high(T)): return
    if bd < int64(low(T)) or bd > int64(high(T)): return
    let a = Fixed[T, FracBits](data: T(ad))
    let b = Fixed[T, FracBits](data: T(bd))
    let want = bigRoute(ad, bd, FracBits)
    let inRange = want.fits and want.value >= int64(low(T)) and
                  want.value <= int64(high(T))
    if inRange:
      let got = a * b
      if int64(got.data) != want.value:
        checkpoint kind & ": " & $ad & " * " & $bd & " >> " & $FracBits &
                   " gave " & $int64(got.data) & ", BigInt route " & $want.value
      check int64(got.data) == want.value
    else:
      expect OverflowDefect:
        discard a * b

  test "int64 storage, Q32.32, over the boundary values":
    for ad in edges:
      for bd in edges:
        probe[int64, 32](ad, bd, "int64/Q32.32")

  test "int64 storage across several scales":
    for frac in 0 .. 3:
      for ad in edges:
        for bd in edges:
          case frac
          of 0: probe[int64, 0](ad, bd, "int64/Q.0")
          of 1: probe[int64, 1](ad, bd, "int64/Q.1")
          of 2: probe[int64, 63](ad, bd, "int64/Q.63")
          else: probe[int64, 64](ad, bd, "int64/Q.64")

  test "narrower storage keeps its own overflow boundary":
    for ad in edges:
      for bd in edges:
        probe[int32, 16](ad, bd, "int32/Q16.16")
        probe[int16, 8](ad, bd, "int16/Q8.8")
        probe[int8, 4](ad, bd, "int8/Q4.4")

  test "randomised operands":
    var state = 0x853C49E6748FEA9B'u64
    proc nextI64(): int64 =
      state = state * 6364136223846793005'u64 + 1442695040888963407'u64
      cast[int64](state)
    for trial in 0 .. 3000:
      let ad = nextI64()
      let bd = nextI64()
      probe[int64, 32](ad, bd, "random int64/Q32.32")
      probe[int64, 16](ad, bd, "random int64/Q16")
      probe[int32, 16](ad shr 33, bd shr 33, "random int32/Q16.16")

  test "negative products round toward negative infinity, not toward zero":
    # (-1) * 1 at Q.1 is -0.5, which floors to -1 and truncates to 0.
    let a = Fixed[int64, 1](data: -1'i64)
    let b = Fixed[int64, 1](data: 1'i64)
    check int64((a * b).data) == -1
    # Same shape one scale up.
    let c = Fixed[int64, 4](data: -1'i64)
    let d = Fixed[int64, 4](data: 8'i64)
    check int64((c * d).data) == -1
