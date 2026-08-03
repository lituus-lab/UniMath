# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## BigFloat comparison. The ordering carries only the trichotomy postcondition
## (`result in {-1, 0, 1}`). Per the recursion doctrine, the antisymmetry
## `cmp(a,b) == -cmp(b,a)` and the equality bridge `cmp(a,b)==0 iff a == b`
## are NOT asserted here: the latter would call the contracted `==` (which
## calls `cmp`) and re-enter the contract. Both are exercised externally in
## `tests/`. Compiled away under `-d:release`.
import contracts
import big_float
import ../arithmetic

func cmp*(a, b: BigFloat): int {.contractual.} =
  ## Total order on `BigFloat`. Returns -1, 0, or 1. Compares signs first, then
  ## aligned magnitudes via the non-contracted `cmp(BigUInt)`.
  ensure:
    result >= -1 and result <= 1
  body:
    if a.isZero:
      if b.isZero: return 0
      return if b.sign: 1 else: -1
    if b.isZero:
      return if a.sign: -1 else: 1

    if a.sign != b.sign:
      return if a.sign: -1 else: 1

    # Same sign, compare magnitudes M * 2^E. The mantissa is normalized (high
    # bit set), so the value's MSB position is `exponent + bitLength(mantissa)
    # - 1`. Compare that first; when equal, align the mantissas (the exponent
    # gap is then exactly the bit-length gap) and compare with the
    # non-contracted `cmp(BigUInt)`.
    let bitsA = bitLength(a.mantissa)
    let bitsB = bitLength(b.mantissa)
    let msbA = a.exponent + int64(bitsA) - 1
    let msbB = b.exponent + int64(bitsB) - 1
    if msbA > msbB:
      result = 1
    elif msbA < msbB:
      result = -1
    elif a.exponent > b.exponent:
      result = cmp(a.mantissa shl Natural(int(a.exponent - b.exponent)), b.mantissa)
    elif a.exponent < b.exponent:
      result = cmp(a.mantissa, b.mantissa shl Natural(int(b.exponent - a.exponent)))
    else:
      result = cmp(a.mantissa, b.mantissa)

    if a.sign: result = -result

func `==`*(a, b: BigFloat): bool {.inline.} = cmp(a, b) == 0
func `<`*(a, b: BigFloat): bool {.inline.} = cmp(a, b) < 0
func `<=`*(a, b: BigFloat): bool {.inline.} = cmp(a, b) <= 0
func `>`*(a, b: BigFloat): bool {.inline.} = cmp(a, b) > 0
func `>=`*(a, b: BigFloat): bool {.inline.} = cmp(a, b) >= 0
