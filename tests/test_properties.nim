# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Randomized property suite (cross-backend invariants). The PRNG is a fixed-
## seed xorshift64 so the run is deterministic and reproducible in CI; the
## iteration count is modest (200) to keep the gate fast. Invariants are chosen
## to be exact on the integer/rational data (commutativity, cancellation,
## distribution) so the checks are equality, not tolerance; the conversion
## round-trips pick dyadic / on-grid inputs so the result is exact too.
import std/[unittest, math]
import UniMath

# ------------------------------------------------------------------------------
# Deterministic xorshift64 (fixed seed).
# ------------------------------------------------------------------------------
var rngState: uint64 = 0x2545F4914F6CDD1Du64

proc xrng(): uint64 =
  var x = rngState
  x = x xor (x shl 13)
  x = x xor (x shr 7)
  x = x xor (x shl 17)
  rngState = x
  x

proc randI64(): int64 = cast[int64](xrng()) # full-range int64
proc randSmall(): int64 = # ~[-2^27, 2^27]
  (cast[int64](xrng() shr 1) mod (1'i64 shl 28)) - (1'i64 shl 27)

# Iteration count: 200 in the default gate, overridable via `-d:propIters=N`
# for the heavier standalone `prop` task.
const propIters {.intdefine.} = 200

suite "properties — BigInt (exact integer algebra)":
  test "add cancels and commutes":
    for _ in 1 .. propIters:
      let a = initBigInt(randI64())
      let b = initBigInt(randI64())
      check (a + b) - b == a
      check a + b == b + a

  test "mul commutes and distributes over add":
    for _ in 1 .. propIters:
      let a = initBigInt(randSmall())
      let b = initBigInt(randSmall())
      let c = initBigInt(randSmall())
      check a * b == b * a
      check a * (b + c) == a * b + a * c

  test "neg and abs round-trip":
    for _ in 1 .. propIters:
      let a = initBigInt(randI64())
      check -(-a) == a
      check abs(-a) == abs(a)

suite "properties — Fixed[int64, 32] (exact integer data)":
  test "add commutes, cancels, and has zero identity":
    for _ in 1 .. propIters:
      let x = toFixed[int64, 32](randSmall())
      let y = toFixed[int64, 32](randSmall())
      let zero = toFixed[int64, 32](0)
      check toFloat64(x + y) == toFloat64(y + x) # same integer data
      check toFloat64((x + y) - y) == toFloat64(x)
      check toFloat64(x + zero) == toFloat64(x)
      check toFloat64(x - x) == 0.0

suite "properties — Rational[BigInt] (exact fraction algebra)":
  test "add cancels; mul commutes and inverts":
    for _ in 1 .. propIters:
      let n1 = initBigInt(randSmall())
      let d1 = initBigInt(int64((xrng() mod 1_000_000_000'u64) + 1))
      let n2 = initBigInt(randSmall())
      let d2 = initBigInt(int64((xrng() mod 1_000_000_000'u64) + 1))
      let r = initRational(n1, d1)
      let s = initRational(n2, d2)
      check r + s == s + r
      check (r + s) - s == r
      check r * s == s * r
      if not isZero(r):
        let inv = initRational(r.den, r.num) # 1/r (sign travels in num)
        check r * inv == initRational(initBigInt(1), initBigInt(1))

suite "properties — conversions (exact round-trips on dyadic / on-grid inputs)":
  test "float64 -> Rational -> float64 is exact for dyadic values":
    for _ in 1 .. propIters:
      let m = randSmall()
      let k = int(xrng() mod 30)
      let v = float64(m) / pow(2.0, float64(k)) # dyadic -> exactly representable
      check toFloat64(toRationalExact(v)) == v

  test "int -> Fixed -> BigFloat -> float64 is exact":
    for _ in 1 .. propIters:
      let n = randSmall()
      check toFloat64(toBigFloat(toFixed[int64, 32](n), 128)) == float64(n)

  test "int64 -> BigFloat -> BigInt truncates back to the integer":
    for _ in 1 .. propIters:
      let k = randSmall() # |k| < 2^27 -> exactly representable in BigFloat
      check toBigInt(initBigFloat(float64(k), 64)) == initBigInt(int64(k))

  test "toInterval encloses toFloat64 of the source":
    for _ in 1 .. propIters:
      let n = randSmall()
      let f = toFixed[int64, 32](n)
      let i = toInterval(f)
      check i.lower <= toFloat64(f) and toFloat64(f) <= i.upper
      let bf = initBigFloat(float64(n), 128)
      let ib = toInterval(bf)
      check ib.lower <= toFloat64(bf) and toFloat64(bf) <= ib.upper
