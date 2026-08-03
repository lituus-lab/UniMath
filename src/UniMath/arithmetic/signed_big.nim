# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Signed arbitrary-precision arithmetic (sign-magnitude). Same-sign adds the
## magnitudes; differing signs subtracts the smaller from the larger. Mul/div
## combine magnitudes with `xor` signs; the remainder takes the dividend's sign.
import ./big_int
import ./addition_big
import ./subtraction_big
import ./comparison_big
import ./multiplication_big
import ./division_big
import ./bitwise_big
import contracts

func equalMag*(a, b: BigInt): bool {.inline.} =
  ## Non-contracted magnitude equality (witness for the subtraction ensure).
  equalLimbs(a.mag, b.mag)

func equalBigInt*(a, b: BigInt): bool {.inline.} =
  ## Non-contracted value equality. Zero is canonical (`isNegative = false`).
  equalMag(a, b) and (a.isNegative == b.isNegative)

func isNegationOf*(a, b: BigInt): bool {.inline.} =
  ## Non-contracted witness: `a == -b`. True iff magnitudes are equal and signs
  ## differ, or both are zero (0 == -0).
  equalMag(a, b) and (a.isNegative != b.isNegative or isZero(a))

func cmp*(a, b: BigInt): int {.contractual.} =
  ensure:
    result >= -1 and result <= 1
  body:
    if isZero(a) and isZero(b): return 0
    if a.isNegative != b.isNegative:
      return if a.isNegative: -1 else: 1
    let cmpMag = cmp(a.mag, b.mag)
    return if a.isNegative: -cmpMag else: cmpMag

func `==`*(a, b: BigInt): bool {.inline.} = cmp(a, b) == 0
func `<`*(a, b: BigInt): bool {.inline.} = cmp(a, b) < 0
func `<=`*(a, b: BigInt): bool {.inline.} = cmp(a, b) <= 0
func `>`*(a, b: BigInt): bool {.inline.} = cmp(a, b) > 0
func `>=`*(a, b: BigInt): bool {.inline.} = cmp(a, b) >= 0

func add*(a, b: BigInt): BigInt {.contractual.} =
  ## Sign-magnitude sum. Zero iff `a` and `b` are additive inverses.
  ensure:
    isZero(result) == isNegationOf(a, b)
  body:
    if a.isNegative == b.isNegative:
      result = initBigInt(a.mag + b.mag, a.isNegative)
    else:
      if a.mag > b.mag:
        result = initBigInt(a.mag - b.mag, a.isNegative)
      elif a.mag < b.mag:
        result = initBigInt(b.mag - a.mag, b.isNegative)
      else:
        result = initBigInt(0)

func `+`*(a, b: BigInt): BigInt {.inline.} = add(a, b)

func sub*(a, b: BigInt): BigInt {.contractual.} =
  ## `a - b = a + (-b)`. Zero iff the operands are equal.
  ensure:
    isZero(result) == equalBigInt(a, b)
  body:
    result = add(a, -b)

func `-`*(a, b: BigInt): BigInt {.inline.} = sub(a, b)

func mul*(a, b: BigInt, algo: MulAlgorithm = Auto): BigInt {.contractual.} =
  ## Sign-magnitude product. Zero iff either factor is zero.
  ensure:
    isZero(result) == (isZero(a) or isZero(b))
  body:
    if isZero(a) or isZero(b): return initBigInt(0)
    let prodMag = mul(a.mag, b.mag, algo)
    let prodSign = a.isNegative != b.isNegative
    result = initBigInt(prodMag, prodSign)

func `*`*(a, b: BigInt): BigInt {.inline.} = mul(a, b)

func divMod*(a, b: BigInt): tuple[q, r: BigInt] {.contractual.} =
  ## Truncated signed division. Quotient sign is `a xor b`; remainder takes the
  ## dividend's sign. Division by zero raises `DivByZeroDefect` (delegated to the
  ## unsigned `divMod`; the ensure is skipped when the body raises).
  ensure:
    isZero(result.r) or (result.r.isNegative == a.isNegative)
    isZero(result.q) or (result.q.isNegative == (a.isNegative != b.isNegative))
  body:
    let (qMag, rMag) = divMod(a.mag, b.mag)
    let qSign = if isZero(qMag): false else: a.isNegative != b.isNegative
    let rSign = if isZero(rMag): false else: a.isNegative
    return (initBigInt(qMag, qSign), initBigInt(rMag, rSign))

func `div`*(a, b: BigInt): BigInt {.contractual, inline.} =
  body:
    let (q, _) = divMod(a, b)
    return q

func `mod`*(a, b: BigInt): BigInt {.contractual, inline.} =
  body:
    let (_, r) = divMod(a, b)
    return r

func `shl`*(a: BigInt, k: Natural): BigInt {.contractual, inline.} =
  ## Left shift: `a * 2^k`, sign preserved.
  ensure:
    isZero(result) == isZero(a)
  body:
    result = initBigInt(a.mag shl k, a.isNegative)

func `shr`*(a: BigInt, k: Natural): BigInt {.contractual, inline.} =
  ## Arithmetic shift right: `floor(a / 2^k)` (sign-extending, matching Nim's
  ## signed `shr` and GMP `mpz_fdiv_q_2exp`). For `a < 0` this is floor division,
  ## not truncation toward zero — callers wanting truncation should use `div`.
  ensure:
    isZero(result) == (isZero(a) or (not a.isNegative and bitLength(a.mag) <= k))
  body:
    if not a.isNegative or isZero(a.mag):
      result = initBigInt(a.mag shr k, false)
    else:
      let m = a.mag shr k
      let dropped = if k == 0: initBigUInt(0'u64)
                    else: a.mag and ((initBigUInt(1'u64) shl k) - initBigUInt(1'u64))
      if isZero(dropped): result = initBigInt(m, true)
      else: result = initBigInt(m + initBigUInt(1'u64), true)

