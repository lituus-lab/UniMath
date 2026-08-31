# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-precision multiplication: schoolbook with `mulAdd` accumulate. `fullMul`
## returns the exact double-width product; `mul` returns the low Bits (wrapping).
import ./limbs
import ./primitives
import ./fixed_int
import ./addition
import contracts

func fullMul*[Bits: static int](a, b: FixedUInt[Bits]): FixedUInt[Bits *
    2] {.contractual.} =
  ## Exact double-width product.
  ensure:
    lowLimb(result) == lowLimb(a) * lowLimb(b)
  body:
    const numLimbs = numLimbs(FixedUInt[Bits])
    for i in 0 ..< numLimbs:
      var carry = ZeroLimb
      for j in 0 ..< numLimbs:
        let k = i + j
        result.limbs[k] = mulAdd(a.limbs[i], b.limbs[j], result.limbs[k], carry)
      result.limbs[i + numLimbs] = carry

func mul*[Bits: static int](a, b: FixedUInt[Bits]): FixedUInt[
    Bits] {.contractual.} =
  ## `(a * b) mod 2^Bits` (low half of the full product).
  ensure:
    lowLimb(result) == lowLimb(a) * lowLimb(b)
  body:
    const numLimbs = numLimbs(FixedUInt[Bits])
    for i in 0 ..< numLimbs:
      var carry = ZeroLimb
      for j in 0 ..< (numLimbs - i):
        let k = i + j
        result.limbs[k] = mulAdd(a.limbs[i], b.limbs[j], result.limbs[k], carry)

func `*`*[Bits: static int](a, b: FixedUInt[Bits]): FixedUInt[Bits] {.inline.} =
  mul(a, b)

func fullMul*[Bits: static int](a, b: FixedInt[Bits]): FixedInt[Bits *
    2] {.contractual.} =
  ## Signed full product: `|a*b|` exact in double width, sign = (a<0) xor (b<0).
  ensure:
    lowLimb(result) == lowLimb(a.toUnsigned()) * lowLimb(b.toUnsigned())
  body:
    let isNegA = isNegative(a)
    let isNegB = isNegative(b)
    let prodUnsigned = fullMul(abs(a), abs(b))
    let prodSigned = prodUnsigned.toSigned()
    if isNegA != isNegB:
      return -prodSigned
    else:
      return prodSigned

func mul*[Bits: static int](a, b: FixedInt[Bits]): FixedInt[
    Bits] {.contractual.} =
  ## Signed wrapping product (the low Bits are the unsigned product's low bits).
  ensure:
    lowLimb(result) == lowLimb(a.toUnsigned()) * lowLimb(b.toUnsigned())
  body:
    mul(a.toUnsigned(), b.toUnsigned()).toSigned()

func `*`*[Bits: static int](a, b: FixedInt[Bits]): FixedInt[Bits] {.inline.} =
  mul(a, b)
