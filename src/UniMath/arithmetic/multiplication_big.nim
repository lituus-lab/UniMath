# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Arbitrary-precision unsigned multiplication: schoolbook (quadratic) and
## Karatsuba (O(n^1.58)) past a limb threshold. `mul` auto-selects.
import ./limbs
import ./primitives
import ./big_int
import ./addition_big
import ./subtraction_big
import contracts

type
  MulAlgorithm* = enum
    Auto, Schoolbook, Karatsuba

func mulSchoolbook*(a, b: BigUInt): BigUInt {.contractual.} =
  ## Schoolbook product. Zero iff either factor is zero.
  ensure:
    isZero(result) == (isZero(a) or isZero(b))
  body:
    if isZero(a) or isZero(b): return initBigUInt(0)
    let numLimbsA = a.limbs.len
    let numLimbsB = b.limbs.len
    # `newSeq` zero-fills the product limbs; the inner loop accumulates into
    # them, so no separate zero pass is needed.
    result.limbs = newSeq[Limb](numLimbsA + numLimbsB)
    for i in 0 ..< numLimbsA:
      var carry = ZeroLimb
      for j in 0 ..< numLimbsB:
        let k = i + j
        result.limbs[k] = mulAdd(a.limbs[i], b.limbs[j], result.limbs[k], carry)
      result.limbs[i + numLimbsB] = carry
    result.trim()
    result

func splitAt(a: BigUInt, m: int): tuple[lo, hi: BigUInt] =
  ## Split `a` into low `m` limbs and the rest.
  if m >= a.limbs.len:
    return (a, initBigUInt(0))
  result.lo = initBigUInt(a.limbs[0 ..< m])
  result.hi = initBigUInt(a.limbs[m ..< a.limbs.len])

func shiftLimbsLeft(a: BigUInt, m: int): BigUInt =
  ## `a * 2^(LimbBits*m)` (shift by whole limbs).
  if isZero(a): return a
  # `newSeq` zero-fills the low `m` limbs; copy `a` into the high part.
  result.limbs = newSeq[Limb](a.limbs.len + m)
  for i in 0 ..< a.limbs.len: result.limbs[i + m] = a.limbs[i]

const KaratsubaThreshold* = 32

func mulKaratsuba*(a, b: BigUInt): BigUInt {.contractual.} =
  ## Karatsuba divide-and-conquer. Zero iff either factor is zero.
  ensure:
    isZero(result) == (isZero(a) or isZero(b))
  body:
    let n = max(a.limbs.len, b.limbs.len)
    if n <= KaratsubaThreshold:
      return mulSchoolbook(a, b)
    let m = n div 2
    let (a0, a1) = splitAt(a, m)
    let (b0, b1) = splitAt(b, m)
    let z0 = mulKaratsuba(a0, b0)
    let z2 = mulKaratsuba(a1, b1)
    let aSum = a0 + a1
    let bSum = b0 + b1
    let z1Temp = mulKaratsuba(aSum, bSum)
    let z1 = z1Temp - z0 - z2
    result = shiftLimbsLeft(z2, 2 * m) + shiftLimbsLeft(z1, m) + z0
    result.trim()

func mul*(a, b: BigUInt, algo: MulAlgorithm = Auto): BigUInt {.contractual.} =
  ## Product; `Auto` picks Karatsuba past the threshold.
  ensure:
    isZero(result) == (isZero(a) or isZero(b))
  body:
    case algo
    of Schoolbook: return mulSchoolbook(a, b)
    of Karatsuba: return mulKaratsuba(a, b)
    of Auto:
      if min(a.limbs.len, b.limbs.len) < KaratsubaThreshold:
        return mulSchoolbook(a, b)
      else:
        return mulKaratsuba(a, b)

func `*`*(a, b: BigUInt): BigUInt {.inline.} =
  mul(a, b)

proc mulInto*(acc: var BigUInt, k: BigUInt) {.contractual.} =
  ## Replace `acc` by its product with `k`. Nim does not expose uniqueness for
  ## seq payloads, so the value API preserves aliases through the allocating
  ## multiplication path. Ownership-aware frontends may specialize safely.
  body:
    acc = acc * k
