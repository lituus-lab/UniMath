# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Arbitrary-precision unsigned comparison. Trimmed operands: more limbs means
## larger; equal length compares most-significant limb first.
import ./big_int
import contracts

func cmp*(a, b: BigUInt): int {.contractual.} =
  ## Unsigned comparison of arbitrary-precision magnitudes. Length decides
  ## first -- the normalised form has no leading zero limbs, so a longer
  ## magnitude is the larger -- then the limbs from the top down.
  ensure:
    result >= -1 and result <= 1
  body:
    if a.limbs.len > b.limbs.len: return 1
    elif a.limbs.len < b.limbs.len: return -1
    for i in countDown(a.limbs.high, 0):
      if a.limbs[i] > b.limbs[i]: return 1
      elif a.limbs[i] < b.limbs[i]: return -1
    return 0

func equalLimbs*(a, b: BigUInt): bool {.inline.} =
  ## Non-contracted limb-array equality (witness for subtraction's ensure).
  a.limbs == b.limbs

func `==`*(a, b: BigUInt): bool {.inline.} = cmp(a, b) == 0
func `<`*(a, b: BigUInt): bool {.inline.} = cmp(a, b) < 0
func `<=`*(a, b: BigUInt): bool {.inline.} = cmp(a, b) <= 0
# `>` and `>=` come from system, derived from `<` and `<=`.

