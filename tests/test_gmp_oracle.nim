# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## BigInt cross-check against the independent GMP oracle. UniMath's own
## `toDecimal` feeds GMP (both sides see the same value), so the comparison
## tests the arithmetic, not the formatter. Run with `nimble testOracle` (needs
## libgmp; not in the default gate).
import std/[unittest, random]
import UniMath
import oracles/oracle

proc dec(b: BigInt): string = toDecimal(b)

suite "BigInt vs GMP — construction":
  test "toDecimal round-trips through GMP":
    let a = initBigInt(-123456789)
    check dec(a) == "-123456789"
    check gmpCmp(dec(a), "-123456789") == 0

suite "BigInt vs GMP — arithmetic":
  test "add/sub/mul of large values":
    let a = initBigInt(1_000_000_000_000) * initBigInt(1_000_000_017)
    let b = initBigInt(999_999_999_981)
    let sa = dec(a)
    let sb = dec(b)
    check dec(a + b) == gmpBinop("add", sa, sb)
    check dec(a - b) == gmpBinop("sub", sa, sb)
    check dec(a * b) == gmpBinop("mul", sa, sb)

  test "signed add/sub":
    let a = initBigInt(-7)
    let b = initBigInt(2)
    check dec(a + b) == gmpBinop("add", dec(a), dec(b))
    check dec(a - b) == gmpBinop("sub", dec(a), dec(b))

suite "BigInt vs GMP — division":
  test "truncated-toward-zero divmod matches mpz_tdiv_qr":
    let a = initBigInt(1_000_000_000_000) * initBigInt(1_000_000_017)
    let b = initBigInt(7)
    let (q, r) = divMod(a, b)
    let (gq, gr) = gmpDivMod(dec(a), dec(b))
    check dec(q) == gq
    check dec(r) == gr
    check gmpReconstruct(dec(a), dec(b), dec(q), dec(r))

  test "signed divmod truncation":
    let (q, r) = divMod(initBigInt(-7), initBigInt(2))
    check dec(q) == "-3"
    check dec(r) == "-1"
    check gmpReconstruct("-7", "2", dec(q), dec(r))

  test "multi-limb divisor: exact multiple (zero remainder)":
    # ~80-bit divisor (two limbs); the dividend is an exact multiple, so the
    # Knuth D remainder window denormalizes to zero and the add-back path is
    # not taken.
    let b = initBigInt(1_000_000_000_000) * initBigInt(1_000_000_017)
    let a = b * initBigInt(123_456_789_012)
    let (q, r) = divMod(a, b)
    check dec(q) == "123456789012"
    check dec(r) == "0"
    check gmpReconstruct(dec(a), dec(b), dec(q), dec(r))

  test "multi-limb divisor: quotient larger than the divisor":
    # Three-limb dividend over a two-limb divisor exercises the full
    # normalize / qhat / multiply-subtract / denormalize pipeline.
    let b = initBigInt(1_000_000_000_000) * initBigInt(1_000_000_017)
    let a = b * initBigInt(123_456_789_012) + initBigInt(7)
    let (q, r) = divMod(a, b)
    let (gq, gr) = gmpDivMod(dec(a), dec(b))
    check dec(q) == gq
    check dec(r) == gr
    check gmpReconstruct(dec(a), dec(b), dec(q), dec(r))

suite "BigInt vs GMP — comparison":
  test "cmp signs and magnitudes":
    check cmp(initBigInt(-5), initBigInt(5)) == gmpCmp("-5", "5")
    check cmp(initBigInt(5), initBigInt(5)) == gmpCmp("5", "5")
    check cmp(initBigInt(5), initBigInt(-5)) == gmpCmp("5", "-5")

suite "BigInt vs GMP — randomized":
  test "mul of random int64 pairs":
    randomize(20260722)
    for _ in 0 ..< 200:
      # Halved bounds: `rand(HSlice)` spans the slice with signed arithmetic,
      # and `high(int64) - low(int64)` overflows int64.
      let x = rand(low(int64) div 2 .. high(int64) div 2)
      let y = rand(low(int64) div 2 .. high(int64) div 2)
      let a = initBigInt(x)
      let b = initBigInt(y)
      check dec(a * b) == gmpBinop("mul", dec(a), dec(b))

  test "divmod of random multi-limb pairs matches mpz_tdiv_qr":
    # Factors above 2^32 keep every product over 64 bits, so both operands
    # span at least two limbs and the multi-limb Knuth D path is exercised.
    randomize(20260722)
    let lo = int64(1) shl 32
    for _ in 0 ..< 200:
      var a = initBigInt(rand(lo .. high(int64)))
      for _ in 0 ..< 2:
        a = a * initBigInt(rand(lo .. high(int64)))
      var b = initBigInt(rand(lo .. high(int64)))
      b = b * initBigInt(rand(lo .. high(int64)))
      let (q, r) = divMod(a, b)
      let (gq, gr) = gmpDivMod(dec(a), dec(b))
      check dec(q) == gq
      check dec(r) == gr
      check gmpReconstruct(dec(a), dec(b), dec(q), dec(r))
