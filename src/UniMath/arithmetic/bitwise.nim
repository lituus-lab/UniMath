# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-precision bitwise ops and shifts. Logical ops are limb-parallel; shifts
## move whole limbs then residual bits. Each `ensure:` is a cheap non-contracted
## consequence only (recursion doctrine: ensures never call a contracted proc).
import ./limbs
import ./fixed_int
import contracts

func `and`*[Bits: static int, T: AnyFixed[Bits]](a, b: T): T {.contractual.} =
  ## Bitwise AND. Zero if either operand is zero (AND only clears bits).
  ensure:
    (not (isZero(a) or isZero(b))) or isZero(result)
  body:
    for i in 0 ..< a.limbs.len:
      result.limbs[i] = a.limbs[i] and b.limbs[i]

func `or`*[Bits: static int, T: AnyFixed[Bits]](a, b: T): T {.contractual.} =
  ## Bitwise OR. Zero iff both operands are zero.
  ensure:
    isZero(result) == (isZero(a) and isZero(b))
  body:
    for i in 0 ..< a.limbs.len:
      result.limbs[i] = a.limbs[i] or b.limbs[i]

func `xor`*[Bits: static int, T: AnyFixed[Bits]](a, b: T): T {.contractual.} =
  ## Bitwise XOR. Zero iff the limb arrays are identical.
  ensure:
    isZero(result) == (a.limbs == b.limbs)
  body:
    for i in 0 ..< a.limbs.len:
      result.limbs[i] = a.limbs[i] xor b.limbs[i]

func `not`*[Bits: static int, T: AnyFixed[Bits]](a: T): T {.contractual.} =
  ## One's complement. No ensure: `isZero(~a)` holds only for the all-ones
  ## value, with no clean non-contracted witness.
  body:
    for i in 0 ..< a.limbs.len:
      result.limbs[i] = not a.limbs[i]

func `shl`*[Bits: static int, T: AnyFixed[Bits]](a: T,
    k: Natural): T {.contractual.} =
  ## Left shift. No ensure: fixed-width truncation can produce zero from a
  ## nonzero input when the shifted bits leave the register (e.g. the top bit
  ## shifted out past `Bits`), with no clean non-contracted witness — matching
  ## `not` and `FixedUInt.shr`.
  body:
    if k == 0: return a
    if k >= Bits: return
    let w = k div LimbBits
    let shift = k mod LimbBits
    if shift == 0:
      for i in countDown(int(a.limbs.high), w):
        result.limbs[i] = a.limbs[i - w]
    else:
      for i in countDown(int(a.limbs.high), w + 1):
        result.limbs[i] = (a.limbs[i - w] shl shift) or
            (a.limbs[i - w - 1] shr (LimbBits - shift))
      result.limbs[w] = a.limbs[0] shl shift

func `shr`*[Bits: static int](a: FixedUInt[Bits], k: Natural): FixedUInt[
    Bits] {.contractual.} =
  ## Logical right shift. No ensure: the true zero-postcondition needs
  ## `bitLength(a) <= k`, and the fixed-width types have no non-contracted
  ## `bitLength`; the weaker `k >= Bits` is false for `a=1, k=1`.
  body:
    if k == 0: return a
    if k >= Bits: return
    let w = k div LimbBits
    let shift = k mod LimbBits
    if shift == 0:
      for i in 0 .. (int(a.limbs.high) - w):
        result.limbs[i] = a.limbs[i + w]
    else:
      for i in 0 ..< (int(a.limbs.high) - w):
        result.limbs[i] = (a.limbs[i + w] shr shift) or
            (a.limbs[i + w + 1] shl (LimbBits - shift))
      result.limbs[int(a.limbs.high) - w] = a.limbs[a.limbs.high] shr shift

func `shr`*[Bits: static int](a: FixedInt[Bits], k: Natural): FixedInt[
    Bits] {.contractual.} =
  ## Arithmetic (sign-extending) right shift. A zero dividend stays zero.
  ensure:
    not isZero(a) or isZero(result)
  body:
    if k == 0: return a
    let isNeg = isNegative(a)
    let fillLimb = if isNeg: MaxLimb else: ZeroLimb
    if k >= Bits:
      for i in 0 ..< result.limbs.len:
        result.limbs[i] = fillLimb
      return
    let w = k div LimbBits
    let shift = k mod LimbBits
    if shift == 0:
      for i in 0 .. (int(a.limbs.high) - w):
        result.limbs[i] = a.limbs[i + w]
      for i in (int(a.limbs.high) - w + 1) .. int(a.limbs.high):
        result.limbs[i] = fillLimb
    else:
      for i in 0 ..< (int(a.limbs.high) - w):
        result.limbs[i] = (a.limbs[i + w] shr shift) or
            (a.limbs[i + w + 1] shl (LimbBits - shift))
      let topLimb = a.limbs[a.limbs.high]
      result.limbs[int(a.limbs.high) - w] = (topLimb shr shift) or
          (fillLimb shl (LimbBits - shift))
      for i in (int(a.limbs.high) - w + 1) .. int(a.limbs.high):
        result.limbs[i] = fillLimb
