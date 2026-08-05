# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed cross-check against the independent GMP oracle. Compares the raw
## `.data` of Nim Fixed `*`/`/` against GMP's exact `(a*b) >> frac` (arithmetic
## / floor shift) and `(a << frac) / b` (truncated toward zero). Run with
## `nimble testOracle` (needs libgmp; not in the default gate).
import std/[unittest, random]
import UniMath
import oracles/oracle

# Decimal of a Fixed `.data` storage value, uniform across int and BigInt
# storage: lift to BigInt, then `toDecimal`.
proc decData[T; FracBits: static[int]](f: Fixed[T, FracBits]): string =
  toDecimal(toBigInt(f.data))

suite "Fixed vs GMP — mul":
  test "int64 Q32.32 mul":
    const FB = 32
    let a = toFixed[int64, FB](123456)
    let b = toFixed[int64, FB](789)
    let p = a * b
    check decData(p) == gmpFixedMul(FB, decData(a), decData(b))
  test "BigInt Q16 mul of large values":
    const FB = 16
    let n = initBigInt(1_000_000_000_000_000_000) # 1e18 fits int64
    let a = initFixed[BigInt, FB](n shl Natural(FB))
    let b = initFixed[BigInt, FB](n shl Natural(FB))
    let p = a * b
    check decData(p) == gmpFixedMul(FB, decData(a), decData(b))

suite "Fixed vs GMP — div":
  test "int64 Q32.32 div truncates toward zero":
    const FB = 32
    let a = toFixed[int64, FB](7)
    let b = toFixed[int64, FB](2)
    let q = a / b
    check decData(q) == gmpFixedDiv(FB, decData(a), decData(b))
  test "BigInt Q16 div of large values":
    const FB = 16
    let n = initBigInt(1_000_000_000_000_000_000)
    let a = initFixed[BigInt, FB](n shl Natural(FB))
    let b = initFixed[BigInt, FB](initBigInt(7) shl Natural(FB))
    let q = a / b
    check decData(q) == gmpFixedDiv(FB, decData(a), decData(b))

suite "Fixed vs GMP — randomized":
  test "BigInt Q16 mul/div of random data":
    const FB = 16
    randomize(20260722)
    for _ in 0 ..< 200:
      let x = rand(low(int32) .. high(int32))
      let y = rand(low(int32) .. high(int32))
      let a = initFixed[BigInt, FB](initBigInt(x) shl Natural(FB))
      let b = initFixed[BigInt, FB](initBigInt(y) shl Natural(FB))
      check decData(a * b) == gmpFixedMul(FB, decData(a), decData(b))
      if y != 0:
        check decData(a / b) == gmpFixedDiv(FB, decData(a), decData(b))
