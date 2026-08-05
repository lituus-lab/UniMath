# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## BigFloat formatting: `toFloat64` (correctly rounded, ties-to-even, with
## subnormal bit-packing) and `$`. `toFloat64` carries the zero/sign
## postcondition over cheap consequences (`isZero`, `signbit`). Compiled away
## under `-d:release`.
import contracts
import std/math
import big_float
import ../arithmetic

func toFloat64*(a: BigFloat): float64 {.contractual.} =
  ## Convert to float64, correctly rounded (nearest, ties-to-even). Returns
  ## ±Inf on overflow, ±0 on underflow (including the subnormal band below
  ## `2^-1075`), 0 for zero.
  ##
  ## The value is `mantissa * 2^exponent`, mantissa normalized (top bit set);
  ## its MSB sits at binary exponent `eTop = exponent + bitLength(mantissa) -
  ## 1`. The range gates use `eTop`, not the bare storage `exponent` — a
  ## high-precision BigFloat holding exactly 1.0 has `exponent = -(precision-1)`
  ## but `eTop = 0`, so a bare-`exponent` short-circuit would misclassify it as
  ## underflow.
  ##
  ## Subnormal results are produced by direct bit-packing of the once-rounded
  ## full mantissa, not by `float64(mm) * pow2f64(e)`: that product zeroes the
  ## whole subnormal band because `pow2f64(e)` underflows to 0 for `e <= -1075`
  ## even when `mm * 2^e` is a representable subnormal. Re-rounding an
  ## already-53-bit `mm` would double-round, so the subnormal path rounds the
  ## full mantissa to the `2^-1074` quantum in one step.
  ensure:
    (not a.isZero) or (result == 0.0)
    a.isZero or result == 0.0 or signbit(result) == a.sign
  body:
    if a.isZero: return 0.0

    let bl = bitLength(a.mantissa) # == precision for a normalized BigFloat
    let eTop = a.exponent + int64(bl) - 1 # binary exponent of the value's MSB

    # Coarse short-circuit on the true MSB exponent (avoids int64→int overflow
    # on 32-bit targets and giant BigInt shifts for values clearly outside the
    # float64 range).
    if eTop > 1023:
      return if a.sign: -Inf else: Inf
    if eTop < -1076: # entire value < 2^-1075 rounds to 0 (ties-to-even)
      return if a.sign: -0.0 else: 0.0

    if eTop >= -1022:
      # Normal range: `float64(mm) * pow2f64(e)` is exact (both factors exact,
      # product inside the normal range).
      const sigBits = 53
      if bl <= sigBits:
        let res = float64(a.mantissa.toUInt64()) * pow2f64(int(a.exponent))
        return if a.sign: -res else: res

      let shift = bl - sigBits # >= 1
      let guardShift = shift - 1
      let mant = a.mantissa shr Natural(guardShift)
      let m = mant.toUInt64() shr 1 # 53-bit significand
      let guardBit = mant.toUInt64() and 1'u64
      let sticky = not isZero(a.mantissa and
        ((initBigUInt(1'u64) shl Natural(guardShift)) - initBigUInt(1'u64)))
      var mm = m
      if guardBit == 1 and (sticky or (mm and 1) == 1):
        mm += 1
      let e = int(a.exponent) + shift # value = mm * 2^e
      let res = float64(mm) * pow2f64(e)
      return if a.sign: -res else: res
    else:
      # Subnormal range (eTop in -1075 .. -1023): single-round the full
      # mantissa to the 2^-1074 quantum, then bit-pack the result.
      # value = mantissa * 2^exponent = k * 2^-1074 with k = round(mantissa * 2^adj)
      let adj = int(a.exponent) + 1074
      var k: uint64
      if adj >= 0:
        # Exact left shift; k has eTop+1075 <= 52 bits, fits uint64.
        k = (a.mantissa shl Natural(adj)).toUInt64()
      else:
        let n = -adj # shift right by n, round to even
        let guardShift = n - 1
        let mant = a.mantissa shr Natural(guardShift) # <= 53 bits, fits uint64
        let m64 = mant.toUInt64()
        k = m64 shr 1
        let guardBit = m64 and 1'u64
        let sticky = if guardShift == 0: false
                     else: not isZero(a.mantissa and
                       ((initBigUInt(1'u64) shl Natural(guardShift)) -
                           initBigUInt(1'u64)))
        if guardBit == 1 and (sticky or (k and 1) == 1):
          k += 1
      # k in [0, 2^52]. k == 2^52 carries to the smallest normal (exp field 1,
      # fraction 0); k == 0 is a true zero (the eTop = -1075 ties-to-even case).
      var storedExp, fraction: uint64
      if k >= (uint64(1) shl 52):
        storedExp = 1'u64
        fraction = 0'u64
      else:
        storedExp = 0'u64
        fraction = k
      let res = cast[float64]((storedExp shl 52) or fraction)
      return if a.sign: -res else: res

func `$`*(a: BigFloat): string =
  ## String representation of BigFloat.
  if a.isZero: return "0.0"
  $a.toFloat64()
