# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Overflow-safe 128-bit helpers for bounded integer types. The cross-products
## of two 64-bit integers (e.g. a `Rational[int64]` comparison) need 128 bits to
## stay exact; computing them in the native width silently wraps (F48). Reuses
## `mulWide` (schoolbook on 32-bit halves, no platform uint128). Also hosts the
## pure-Nim `pow2f64` scaler for correctly-rounded `toFloat64`.
import std/math
import ./limbs
import ./primitives
import contracts

func mul128*(a, b: uint64): tuple[lo, hi: uint64] {.contractual, inline.} =
  ## Full 128-bit unsigned product `a * b`. The low 64 bits equal the native
  ## wrapped product; the high 64 bits are the carry.
  ensure:
    result.lo == a * b
  body:
    var hi: Limb
    let lo = mulWide(Limb(a), Limb(b), hi)
    result = (uint64(lo), uint64(hi))

func cmpMul128*(a, b, c, d: uint64): int {.contractual, inline.} =
  ## Compares `a * b` against `c * d` as exact 128-bit unsigned values. Never
  ## overflows — a naive 64-bit `a*b` / `c*d` would wrap and compare the wrong
  ## values (F48).
  ensure:
    result >= -1 and result <= 1
  body:
    let pa = mul128(a, b)
    let pc = mul128(c, d)
    if pa.hi != pc.hi:
      return if pa.hi < pc.hi: -1 else: 1
    if pa.lo != pc.lo:
      return if pa.lo < pc.lo: -1 else: 1
    return 0

func absToU64*(v: SomeSignedInt): uint64 {.contractual, inline.} =
  ## `|v|` as `uint64`, MinInt-safe (two's-complement magnitude via `not + 1`).
  ensure:
    (v >= 0 and result == uint64(v)) or (v < 0 and result == (not uint64(v)) + 1'u64)
  body:
    if v >= 0: uint64(v)
    else: (not uint64(v)) + 1'u64

func absToU64*(v: SomeUnsignedInt): uint64 {.contractual, inline.} =
  ## `|v|` as `uint64` for unsigned storage — the value itself (no sign bit).
  ensure:
    result == uint64(v)
  body:
    uint64(v)

func pow2f64*(e: int): float64 {.contractual, inline.} =
  ## Exact float64 `2^e`. +Inf for `e >= 1024`, +0 for `e <= -1075`, subnormal
  ## for `e in [-1074, -1023]`, normal otherwise. Pure-Nim IEEE-754 bit packing
  ## (replaces the platform `ldexp`, absent from Nim's std/math).
  ensure:
    (e >= 1024 and result == Inf) or
    (e <= -1075 and result == 0.0) or
    (e >= -1022 and e < 1024 and classify(result) == fcNormal and result >
        0.0) or
    (e < -1022 and e > -1075 and result > 0.0 and result < 1.0)
  body:
    if e >= 1024:
      return cast[float64](0x7FF0_0000_0000_0000'u64)
    if e <= -1075:
      return 0.0
    if e >= -1022:
      result = cast[float64](uint64(e + 1023) shl 52)
    else:
      result = cast[float64](uint64(1) shl uint(e + 1074))

func mulShiftRightSigned*(a, b: int64, shift: int): int64 {.contractual, inline.} =
  ## `(a * b) >> shift` with a 128-bit intermediate and an arithmetic
  ## (sign-preserving, floor) right shift. The native `int64 * int64` wraps for
  ## products above 2^63 (F41); this stays exact. A negative `shift` raises
  ## `ValueError` (body raise — a correctness-critical guard, survives release).
  ensure:
    result == 0 or ((result < 0) == ((a < 0) xor (b < 0)))
  body:
    if shift < 0:
      raise newException(ValueError,
        "mulShiftRightSigned: shift must be non-negative, got " & $shift)
    let neg = (a < 0) xor (b < 0)
    let (lo, hi) = mul128(absToU64(a), absToU64(b))
    if shift == 0:
      # `a*b` itself: the full magnitude `hi*2^64 + lo` must fit int64. 2^63 is
      # representable only as the negative `low(int64)`; everything above 2^63
      # (or 2^63-1 for a positive result) overflows and raises.
      if hi != 0:
        raise newException(OverflowDefect,
          "mulShiftRightSigned: result exceeds int64 range")
      if neg:
        if lo > (uint64(1) shl 63):
          raise newException(OverflowDefect,
            "mulShiftRightSigned: result exceeds int64 range")
        if lo == (uint64(1) shl 63): return low(int64)
        return -int64(lo)
      else:
        if lo >= (uint64(1) shl 63):
          raise newException(OverflowDefect,
            "mulShiftRightSigned: result exceeds int64 range")
        return int64(lo)
    if shift >= 128:
      # All magnitude bits are discarded; the arithmetic (sign-preserving) shift
      # saturates to -1 for a negative product and 0 for a nonnegative one.
      # `neg` is the sign of the operands, not of the product: one operand zero
      # with the other negative makes it true for the product 0, whose floor is
      # 0, not -1. Test the magnitude first.
      if lo == 0'u64 and hi == 0'u64: return 0'i64
      return if neg: -1'i64 else: 0'i64
    # M = (hi*2^64 + lo) >> shift, split as (mLo, mHi) with M = mHi*2^64 + mLo.
    # `hasRem` flags any nonzero bit discarded by the shift (the ceil term for a
    # negative floor result). The result fits int64 iff M (plus the ceil term
    # for neg) is <= 2^63; 2^63 is representable only as `low(int64)`.
    var mLo, mHi: uint64
    var hasRem: bool
    if shift >= 64:
      mLo = hi shr (shift - 64)
      mHi = 0'u64
      let r = if shift > 64: hi and ((uint64(1) shl (shift - 64)) - 1) else: 0'u64
      hasRem = (r != 0) or (lo != 0)
    else:
      mLo = (lo shr shift) or (hi shl (64 - shift))
      mHi = hi shr shift
      hasRem = (lo and ((uint64(1) shl shift) - 1)) != 0
    if mHi != 0:
      raise newException(OverflowDefect,
        "mulShiftRightSigned: result exceeds int64 range")
    if neg:
      if mLo > (uint64(1) shl 63):
        raise newException(OverflowDefect,
          "mulShiftRightSigned: result exceeds int64 range")
      if mLo == (uint64(1) shl 63):
        if hasRem:
          raise newException(OverflowDefect,
            "mulShiftRightSigned: result exceeds int64 range")
        return low(int64)
      let mag = mLo + (if hasRem: 1'u64 else: 0'u64) # mLo < 2^63, no wrap
      if mag == (uint64(1) shl 63): return low(int64)
      result = -int64(mag)
    else:
      if mLo >= (uint64(1) shl 63):
        raise newException(OverflowDefect,
          "mulShiftRightSigned: result exceeds int64 range")
      result = int64(mLo)

func divmod128by64*(numHi, numLo, d: uint64): tuple[quo,
    rem: uint64] {.contractual.} =
  ## 128-bit dividend ÷ 64-bit divisor (quotient and remainder fit 64 bits).
  ## Used by the LUT linear-interpolation path. Domain guards are body raises
  ## (correctness-critical, survive release): `d == 0`, and on the long-division
  ## path `d >= 2^63` or `numHi >= d` (the loop assumes `rem < d < 2^63`).
  ensure:
    result.rem < d
  body:
    if d == 0:
      raise newException(DivByZeroDefect, "divmod128by64: divisor is zero")
    if numHi == 0:
      return (numLo div d, numLo mod d)
    if d >= (1'u64 shl 63):
      raise newException(ValueError,
        "divmod128by64: divisor must be < 2^63 on the long-division path")
    if numHi >= d:
      raise newException(ValueError,
        "divmod128by64: high limb must be < divisor (quotient must fit 64 bits)")
    var rem, quo: uint64 = 0
    for i in 0 ..< 128:
      let bit = if i < 64: (numHi shr (63 - i)) and 1'u64
                else: (numLo shr (127 - i)) and 1'u64
      rem = (rem shl 1) or bit
      quo = quo shl 1
      if rem >= d:
        rem -= d
        quo = quo or 1'u64
    return (quo, rem)
