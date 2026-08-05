# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Arbitrary-precision integers. `BigUInt` is a heap `seq[Limb]` (little-endian,
## trimmed so zero is `[]`); `BigInt` is sign-magnitude over a `BigUInt`.
import ./limbs
import ./primitives
import contracts

type
  BigUInt* = object
    limbs*: seq[Limb]

  BigInt* = object
    isNegative*: bool
    mag*: BigUInt

func bitLength*(a: BigUInt): int {.inline.} =
  ## Bits needed to represent `a` (0 for zero): highest set bit index + 1.
  ## One `clzLimb` on the top limb (hardware `__builtin_clzll` where available)
  ## instead of a bit-serial scan — this is the hot path of `normalize`, called
  ## after every BigFloat mul/add.
  if a.limbs.len == 0: return 0
  (a.limbs.len - 1) * LimbBits + (LimbBits - clzLimb(a.limbs[^1]))

func trim*(a: var BigUInt) {.inline.} =
  ## Drop leading zero limbs; zero becomes `[]`.
  var i = a.limbs.high
  while i >= 0 and a.limbs[i] == ZeroLimb:
    dec i
  a.limbs.setLen(i + 1)

func initBigUInt*(val: SomeUnsignedInt): BigUInt =
  if val == 0:
    result.limbs = newSeq[Limb](0)
  else:
    result.limbs = @[Limb(val)]

func initBigUInt*(limbs: seq[Limb]): BigUInt =
  result.limbs = limbs
  result.trim()

func isZero*(a: BigUInt): bool {.inline.} =
  a.limbs.len == 0

func initBigInt*(val: SomeSignedInt): BigInt =
  if val == 0:
    result.isNegative = false
    result.mag = initBigUInt(0)
  elif val < 0:
    result.isNegative = true
    let absVal = if val == low(type(val)): (not uint64(val)) + 1 else: uint64(-val)
    result.mag = initBigUInt(absVal)
  else:
    result.isNegative = false
    result.mag = initBigUInt(uint64(val))

func fromInt*(val: int): BigInt {.inline.} =
  initBigInt(val)

func fromFloat*(val: float64): BigInt {.inline.} =
  ## Truncate `val` toward zero to a `BigInt`. The direct `int64(val)` is
  ## undefined outside the int64 range, so range-check first: NaN maps to 0,
  ## and ±Inf or values outside `[low(int64), high(int64)]` raise
  ## `OverflowDefect` deterministically (matching `toInt64`/`toUInt64`).
  if val != val:
    return initBigInt(0) # NaN has no integer value
  if abs(val) == Inf or val < float64(low(int64)) or val >= float64(high(int64)):
    raise newException(OverflowDefect, "fromFloat: value outside int64 range")
  initBigInt(int64(val))

func fromUInt*(val: SomeUnsignedInt): BigInt {.inline.} =
  result.isNegative = false
  result.mag = initBigUInt(val)

func initBigInt*(mag: BigUInt, isNegative: bool = false): BigInt =
  result.mag = mag
  result.isNegative = if isZero(mag): false else: isNegative

func abs*(a: BigInt): BigUInt {.inline.} =
  a.mag

func isZero*(a: BigInt): bool {.inline.} =
  isZero(a.mag)

func toUInt64*(a: BigUInt): uint64 =
  ## Exact conversion; raises `OverflowDefect` if `a > MaxUInt64`.
  if a.isZero: return 0'u64
  if a.limbs.len > 1:
    raise newException(OverflowDefect, "BigUInt exceeds uint64 range")
  return uint64(a.limbs[0])

func toInt64*(a: BigUInt): int64 =
  ## Exact conversion; raises `OverflowDefect` if `a > MaxInt64`.
  if a.isZero: return 0'i64
  if a.limbs.len > 1:
    raise newException(OverflowDefect, "BigUInt exceeds int64 range")
  let lo = a.limbs[0]
  if lo > uint64(high(int64)):
    raise newException(OverflowDefect, "BigUInt exceeds int64 range")
  return int64(lo)

func toUInt64*(a: BigInt): uint64 =
  ## Exact conversion; raises `OverflowDefect` if `a` is negative or `|a| >
  ## MaxUInt64`.
  if a.isNegative:
    raise newException(OverflowDefect, "negative BigInt cannot convert to uint64")
  a.mag.toUInt64()

func toInt64*(a: BigInt): int64 =
  ## Exact conversion; raises `OverflowDefect` outside `[MinInt64, MaxInt64]`.
  ## `MinInt64` is representable (magnitude `2^63`).
  if a.isZero: return 0'i64
  if a.mag.limbs.len > 1:
    raise newException(OverflowDefect, "BigInt exceeds int64 range")
  let lo = a.mag.limbs[0]
  if a.isNegative:
    if lo > (uint64(1) shl 63):
      raise newException(OverflowDefect, "BigInt exceeds int64 range")
    if lo == (uint64(1) shl 63): return low(int64)
    return -int64(lo)
  else:
    if lo > uint64(high(int64)):
      raise newException(OverflowDefect, "BigInt exceeds int64 range")
    return int64(lo)

func `-`*(a: BigInt): BigInt {.contractual, inline.} =
  ## Unary negation (sign flip, magnitude preserved). Zero stays zero.
  ensure:
    isZero(result) == isZero(a)
  body:
    result = initBigInt(a.mag, not a.isNegative)







