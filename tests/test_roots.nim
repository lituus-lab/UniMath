# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Roots tests: integer square root (digit-by-digit) over built-in integers
## and `BigInt`, and the generic Newton-Raphson square root over every
## `OrderedField` (float64, `BigFloat`, `Rational`, `Fixed`).
import std/[unittest, math]
import UniMath

suite "isqrt — digit-by-digit":
  test "built-in integers":
    check isqrt(0'i64) == 0
    check isqrt(1'i64) == 1
    check isqrt(3'i64) == 1
    check isqrt(4'i64) == 2
    check isqrt(8'i64) == 2
    check isqrt(15'i64) == 3
    check isqrt(16'i64) == 4
    check isqrt(1_000_000'i64) == 1000
  test "BigInt":
    check isqrt(initBigInt(0)) == initBigInt(0)
    check isqrt(initBigInt(1)) == initBigInt(1)
    check isqrt(initBigInt(15)) == initBigInt(3)
    check isqrt(initBigInt(16)) == initBigInt(4)
    check isqrt(initBigInt(1_000_000)) == initBigInt(1000)
    # r*r <= n < (r+1)*(r+1) for a non-square.
    let n = initBigInt(1_000_000_000)
    let r = isqrt(n)
    check r * r <= n and n < (r + initBigInt(1)) * (r + initBigInt(1))
  test "negative raises ValueError":
    expect ValueError:
      discard isqrt(-1'i64)
    expect ValueError:
      discard isqrt(initBigInt(-1))

suite "sqrtNewtonGeneric — across OrderedFields":
  test "float64":
    check abs(sqrtNewtonGeneric(4.0) - 2.0) < 1e-12
    check abs(sqrtNewtonGeneric(2.0) - sqrt(2.0)) < 1e-12
    check sqrtNewtonGeneric(0.0) == 0.0
  test "BigFloat":
    let p = 128
    check abs(toFloat64(sqrtNewtonGeneric(initBigFloat(4.0, p))) - 2.0) < 1e-20
    check abs(toFloat64(sqrtNewtonGeneric(initBigFloat(2.0, p))) - sqrt(2.0)) < 1e-20
    check toFloat64(sqrtNewtonGeneric(initBigFloat(0.0, p))) == 0.0
  test "Rational":
    # Exact rational Newton never hits sqrt(4)=2 in finite steps — the
    # iterates stay exact with growing denominators — so cap the iterations
    # (5 converges to ~3e-15) and check the float approximation, not num/den.
    let r = sqrtNewtonGeneric(fromInt(Rational[int64], 4), 5)
    check abs(toFloat64(r) - 2.0) < 1e-9
    let z = sqrtNewtonGeneric(fromInt(Rational[int64], 0))
    check z.isZero
  test "Fixed":
    let s = sqrtNewtonGeneric(fromInt(Fixed[int64, 32], 4))
    check toFloat64(s) == 2.0
  test "negative raises ValueError":
    expect ValueError:
      discard sqrtNewtonGeneric(-1.0)
    expect ValueError:
      discard sqrtNewtonGeneric(initBigFloat(-1.0, 128))
    expect ValueError:
      discard sqrtNewtonGeneric(fromInt(Rational[int64], -1))

suite "isqrt — BigInt Newton path against the digit-by-digit oracle":
  # The BigInt overload is Newton's method; the generic digit-by-digit routine
  # is division-free and shares no arithmetic with it, so it is a genuine
  # oracle rather than the same code under another name. The defining identity
  # r*r <= n < (r+1)^2 is checked directly as well: an oracle that agreed with
  # a wrong implementation would still fail that.

  func refIsqrt(n: BigUInt): BigUInt =
    ## The digit-by-digit algorithm, kept here verbatim so the test does not
    ## depend on which implementation `isqrt` currently selects.
    if isZero(n): return n
    let one = initBigUInt(1'u64)
    var bit = one
    while bit <= n:
      let nextBit = bit shl 2
      if nextBit < bit: break
      bit = nextBit
    if bit > n: bit = bit shr 2
    var res = initBigUInt(0'u64)
    var num = n
    while not isZero(bit):
      if num >= res + bit:
        num = num - (res + bit)
        res = (res shr 1) + bit
      else:
        res = res shr 1
      bit = bit shr 2
    res

  proc check1(n: BigUInt) =
    let r = isqrt(n)
    let want = refIsqrt(n)
    if r != want:
      checkpoint "n has " & $bitLength(n) & " bits"
      check r == want
    # The definition itself, independent of the oracle.
    check r * r <= n
    check (r + initBigUInt(1'u64)) * (r + initBigUInt(1'u64)) > n

  test "every small value, where off-by-one lives":
    for i in 0 .. 4096:
      check1(initBigUInt(uint64(i)))

  test "perfect squares and their neighbours across the range":
    for k in 1 .. 200:
      let base = initBigUInt(uint64(k)) shl Natural(3 * k mod 137)
      let sq = base * base
      check1(sq)
      check1(sq - initBigUInt(1'u64))
      check1(sq + initBigUInt(1'u64))

  test "powers of two, both parities of the exponent":
    for e in 0 .. 400:
      let p = initBigUInt(1'u64) shl Natural(e)
      check1(p)
      if e > 0: check1(p - initBigUInt(1'u64))

  test "randomized, 64 to 1024 bits":
    var state = 0x9E3779B97F4A7C15'u64
    for words in [1, 2, 4, 8, 16]:
      for trial in 0 .. 30:
        var xs = newSeq[Limb](words)
        for i in 0 ..< words:
          state = state * 6364136223846793005'u64 + 1442695040888963407'u64
          xs[i] = state
        check1(initBigUInt(xs))

  test "all-ones operands at several widths":
    for words in [1, 2, 3, 5, 9]:
      var xs = newSeq[Limb](words)
      for i in 0 ..< words: xs[i] = high(uint64)
      check1(initBigUInt(xs))

  test "BigInt wrapper keeps the sign contract":
    check isqrt(initBigInt(0)) == initBigInt(0)
    check isqrt(initBigInt(144)) == initBigInt(12)
    check isqrt(initBigInt(145)) == initBigInt(12)
    expect ValueError:
      discard isqrt(initBigInt(-1))
