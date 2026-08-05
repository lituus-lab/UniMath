# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Arbitrary-precision bitwise ops and shifts. The shorter operand is
## zero-padded; left shift grows, right shift trims.
import ./limbs
import ./big_int
import contracts

func `and`*(a, b: BigUInt): BigUInt {.contractual.} =
  ## Bitwise AND. `bitLength(result) <= min(bitLength(a), bitLength(b))`.
  ensure:
    bitLength(result) <= min(bitLength(a), bitLength(b))
  body:
    let minLen = min(a.limbs.len, b.limbs.len)
    result.limbs = newSeq[Limb](minLen)
    for i in 0 ..< minLen:
      result.limbs[i] = a.limbs[i] and b.limbs[i]
    result.trim()
    result

func `or`*(a, b: BigUInt): BigUInt {.contractual.} =
  ## Bitwise OR. `bitLength(result) == max(bitLength(a), bitLength(b))`.
  ensure:
    bitLength(result) == max(bitLength(a), bitLength(b))
  body:
    let maxLen = max(a.limbs.len, b.limbs.len)
    result.limbs = newSeq[Limb](maxLen)
    for i in 0 ..< maxLen:
      let valA = if i < a.limbs.len: a.limbs[i] else: ZeroLimb
      let valB = if i < b.limbs.len: b.limbs[i] else: ZeroLimb
      result.limbs[i] = valA or valB
    result.trim()
    result

func `xor`*(a, b: BigUInt): BigUInt {.contractual.} =
  ## Bitwise XOR. Zero iff the trimmed operands are equal.
  ensure:
    isZero(result) == (a.limbs == b.limbs)
  body:
    let maxLen = max(a.limbs.len, b.limbs.len)
    result.limbs = newSeq[Limb](maxLen)
    for i in 0 ..< maxLen:
      let valA = if i < a.limbs.len: a.limbs[i] else: ZeroLimb
      let valB = if i < b.limbs.len: b.limbs[i] else: ZeroLimb
      result.limbs[i] = valA xor valB
    result.trim()
    result

func `shl`*(a: BigUInt, k: Natural): BigUInt {.contractual.} =
  ## Left shift by `k` bits (`a * 2^k`). Zero iff `a` is zero.
  ensure:
    isZero(result) == isZero(a)
  body:
    if isZero(a) or k == 0: return a
    let w = k div LimbBits
    let shift = k mod LimbBits
    result.limbs = newSeq[Limb](a.limbs.len + w + 1)
    if shift == 0:
      for i in 0 ..< a.limbs.len:
        result.limbs[i + w] = a.limbs[i]
    else:
      var carry = ZeroLimb
      for i in 0 ..< a.limbs.len:
        result.limbs[i + w] = (a.limbs[i] shl shift) or carry
        carry = a.limbs[i] shr (LimbBits - shift)
      result.limbs[a.limbs.len + w] = carry
    result.trim()
    result

func `shr`*(a: BigUInt, k: Natural): BigUInt {.contractual.} =
  ## Right shift by `k` bits (`floor(a / 2^k)`). Zero iff `a` is zero or
  ## `bitLength(a) <= k`.
  ensure:
    isZero(result) == (isZero(a) or bitLength(a) <= k)
  body:
    if isZero(a) or k == 0: return a
    let w = k div LimbBits
    let shift = k mod LimbBits
    if w >= a.limbs.len:
      return initBigUInt(0)
    let newLen = a.limbs.len - w
    result.limbs = newSeq[Limb](newLen)
    if shift == 0:
      for i in 0 ..< newLen:
        result.limbs[i] = a.limbs[i + w]
    else:
      for i in 0 ..< newLen:
        let curr = a.limbs[i + w] shr shift
        let next = if (i + w + 1) < a.limbs.len: a.limbs[i + w + 1] shl (
            LimbBits - shift)
                   else: ZeroLimb
        result.limbs[i] = curr or next
    result.trim()
    result
