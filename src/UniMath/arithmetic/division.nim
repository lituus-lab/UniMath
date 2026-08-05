# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-precision division: binary long division (base-2 shift-and-subtract).
## Euclidean for unsigned, truncated (toward zero) for signed. Division by zero
## raises `DivByZeroDefect` (body raise, survives release); the MinInt-div-(-1)
## overflow is a body raise. The reconstruction `q*b + r == a` is verified
## externally, not as an inline `ensure:` (it would call the contracted `*`/`+`).
import ./limbs
import ./fixed_int
import ./comparison
import ./addition
import ./bitwise
import contracts

func divMod*[Bits: static int](a, b: FixedUInt[Bits]): tuple[q, r: FixedUInt[
    Bits]] {.contractual.} =
  ## Euclidean `a / b`: `q = floor(a/b)`, `0 <= r < b`.
  body:
    if isZero(b):
      raise newException(DivByZeroDefect, "Division by zero.")
    if a < b:
      return (q: initFixedUInt[Bits](0), r: a)
    var q: FixedUInt[Bits]
    var r: FixedUInt[Bits]
    for i in countDown(Bits - 1, 0):
      r = r shl 1
      let limbIdx = i div LimbBits
      let bitIdx = i mod LimbBits
      let bitVal = (a.limbs[limbIdx] shr bitIdx) and 1
      if bitVal == 1:
        r.limbs[0] = r.limbs[0] or 1
      if r >= b:
        r = r - b
        q.limbs[limbIdx] = q.limbs[limbIdx] or (OneLimb shl bitIdx)
    return (q, r)

func `div`*[Bits: static int](a, b: FixedUInt[Bits]): FixedUInt[
    Bits] {.contractual, inline.} =
  body:
    let (q, _) = divMod(a, b)
    return q

func `mod`*[Bits: static int](a, b: FixedUInt[Bits]): FixedUInt[
    Bits] {.contractual, inline.} =
  body:
    let (_, r) = divMod(a, b)
    return r

func divMod*[Bits: static int](a, b: FixedInt[Bits]): tuple[q, r: FixedInt[
    Bits]] {.contractual.} =
  ## Truncated (toward zero) signed division; remainder takes the dividend's sign.
  body:
    let isNegA = isNegative(a)
    let isNegB = isNegative(b)
    let absA = abs(a)
    let absB = abs(b)
    let (qUnsigned, rUnsigned) = divMod(absA, absB)
    # Apply the quotient sign to the unsigned magnitude before narrowing to
    # signed: building the two's-complement pattern directly avoids the checked
    # negation of an already-MinInt value, so `MinInt div 1 = MinInt` (the
    # magnitude 2^(Bits-1) narrows to MinInt) instead of raising on `-MinInt`.
    var qMag = qUnsigned
    if isNegA != isNegB:
      for i in 0 ..< qMag.limbs.len:
        qMag.limbs[i] = not qMag.limbs[i]
      var carry = OneLimb
      for i in 0 ..< qMag.limbs.len:
        let sum = qMag.limbs[i] + carry
        qMag.limbs[i] = sum
        carry = if sum < carry: OneLimb else: ZeroLimb
    let qSigned = qMag.toSigned()
    var rSigned = rUnsigned.toSigned()
    if isNegA:
      rSigned = -rSigned
    # MinInt div -1: the only case where the signed quotient overflows its range.
    if isNegA == isNegB and isNegative(qSigned):
      raise newException(OverflowDefect,
        "FixedInt divMod: quotient overflows signed range (MinInt div -1)")
    return (qSigned, rSigned)

func `div`*[Bits: static int](a, b: FixedInt[Bits]): FixedInt[
    Bits] {.contractual, inline.} =
  body:
    let (q, _) = divMod(a, b)
    return q

func `mod`*[Bits: static int](a, b: FixedInt[Bits]): FixedInt[
    Bits] {.contractual, inline.} =
  body:
    let (_, r) = divMod(a, b)
    return r
