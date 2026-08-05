# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Arbitrary-precision unsigned addition.
import ./limbs
import ./primitives
import ./big_int
import contracts

func add*(a, b: BigUInt): BigUInt {.contractual.} =
  ## Sum of two `BigUInt`. Zero iff both summands are zero.
  ensure:
    isZero(result) == (isZero(a) and isZero(b))
  body:
    let maxLen = max(a.limbs.len, b.limbs.len)
    result.limbs = newSeq[Limb](maxLen + 1)
    var carry = ZeroLimb
    for i in 0 ..< maxLen:
      let valA = if i < a.limbs.len: a.limbs[i] else: ZeroLimb
      let valB = if i < b.limbs.len: b.limbs[i] else: ZeroLimb
      var newCarry: Limb
      result.limbs[i] = addC(carry, valA, valB, newCarry)
      carry = newCarry
    result.limbs[maxLen] = carry
    result.trim()
    result

func `+`*(a, b: BigUInt): BigUInt {.inline.} =
  add(a, b)

