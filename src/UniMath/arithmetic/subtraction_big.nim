# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Arbitrary-precision unsigned subtraction. Requires `a >= b`; raises
## `UnderflowDefect` otherwise (no natural wrap width for a bignum).
import ./limbs
import ./primitives
import ./big_int
import ./comparison_big
import contracts

type
  UnderflowDefect* = object of Defect

func sub*(a, b: BigUInt): BigUInt {.contractual.} =
  ## `a - b`. Zero iff the trimmed operands are equal.
  ensure:
    isZero(result) == equalLimbs(a, b)
  body:
    if a < b:
      raise newException(UnderflowDefect, "Subtraction underflow: a < b in BigUInt")
    result.limbs = newSeq[Limb](a.limbs.len)
    var borrow = ZeroLimb
    for i in 0 ..< a.limbs.len:
      let valB = if i < b.limbs.len: b.limbs[i] else: ZeroLimb
      result.limbs[i] = subB(borrow, a.limbs[i], valB, borrow)
    assert borrow == ZeroLimb, "Unexpected final borrow in BigUInt subtraction"
    result.trim()
    result

func `-`*(a, b: BigUInt): BigUInt {.inline.} =
  sub(a, b)

