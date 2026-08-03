# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Correctly-rounded `BigUInt`/`BigInt` → `float64`. Extracts the top 53 bits
## with a guard bit and a sticky bit (OR of all bits below the guard), rounds to
## nearest (ties-to-even, the IEEE-754 default), and scales by the residual
## exponent with `pow2f64`. Exact for `|a| < 2^53`, correctly rounded beyond;
## ±Inf on overflow, ±0 on underflow. Lives here (not in `big_int`) because it
## needs `shr`/`and` from `bitwise_big`, which imports `big_int`.
import ./big_int
import ./bitwise_big
import ./subtraction_big
import ./wide
import contracts

const ToFloat64SigBits = 53

func toFloat64*(a: BigUInt): float64 {.contractual.} =
  ## Exact for `a < 2^53`; correctly rounded (nearest, ties-to-even) beyond.
  ensure:
    result >= 0.0
    a.isZero == (result == 0.0)
  body:
    if a.isZero: return 0.0
    let bl = bitLength(a)
    if bl <= ToFloat64SigBits:
      return float64(a.toUInt64())
    let shift = bl - ToFloat64SigBits
    let guardShift = shift - 1
    let window = a shr guardShift
    let m = window.toUInt64() shr 1
    let guardBit = window.toUInt64() and 1'u64
    let sticky =
      if guardShift == 0: false
      else: not isZero(a and ((initBigUInt(1'u64) shl guardShift) - initBigUInt(1'u64)))
    var mm = m
    if guardBit == 1 and (sticky or (mm and 1) == 1):
      mm += 1
    result = float64(mm) * pow2f64(shift)

func toFloat64*(a: BigInt): float64 {.contractual.} =
  ## Sign-magnitude → float64. Sign from `a.isNegative`; magnitude via the
  ## unsigned `toFloat64`.
  ensure:
    a.isZero == (result == 0.0)
    a.isZero or ((result < 0.0) == a.isNegative)
  body:
    let res = a.mag.toFloat64()
    return if a.isNegative: -res else: res








