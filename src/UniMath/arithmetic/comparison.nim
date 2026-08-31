# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-precision comparison: most-significant limb first.
import ./limbs
import ./fixed_int
import contracts

func cmp*[Bits: static int](a, b: FixedUInt[Bits]): int {.contractual, inline.} =
  ## Unsigned comparison, most significant limb first. Returns -1, 0 or 1.
  ensure:
    result >= -1 and result <= 1
  body:
    for i in countDown(a.limbs.high, 0):
      if a.limbs[i] > b.limbs[i]: return 1
      elif a.limbs[i] < b.limbs[i]: return -1
    return 0

func cmp*[Bits: static int](a, b: FixedInt[Bits]): int {.contractual, inline.} =
  ## Two's-complement signed comparison: differing signs decide, equal signs
  ## compare lexicographically (two's complement preserves order within a sign).
  ensure:
    result >= -1 and result <= 1
  body:
    const signShift = LimbBits - 1
    let signA = a.limbs[^1] shr signShift
    let signB = b.limbs[^1] shr signShift
    if signA != signB:
      return if signA == 0: 1 else: -1
    for i in countDown(a.limbs.high, 0):
      if a.limbs[i] > b.limbs[i]: return 1
      elif a.limbs[i] < b.limbs[i]: return -1
    return 0

template generateComparisons*(T: typedesc) =
  ## Define `==`, `<` and `<=` for `T` in terms of its `cmp`. `>` and `>=`
  ## come from system, derived from these, so three definitions give five
  ## operators and none of them can disagree with `cmp`.
  func `==`*[Bits: static int](a, b: T[Bits]): bool {.inline.} = cmp(a, b) == 0
  func `<`*[Bits: static int](a, b: T[Bits]): bool {.inline.} = cmp(a, b) < 0
  func `<=`*[Bits: static int](a, b: T[Bits]): bool {.inline.} = cmp(a, b) <= 0
  # `>` and `>=` come from system, derived from `<` and `<=`.

generateComparisons(FixedUInt)
generateComparisons(FixedInt)
