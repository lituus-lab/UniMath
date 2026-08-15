# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## BigFloat arithmetic: round-to-nearest operators delegate to the directed-
## rounding primitives (`addRounded`/`subRounded`/`mulRounded`/`divRounded`).
## Each public op carries a postcondition over cheap, non-contracted
## consequences only — zero propagation, the sign rule, and the normalization
## invariant `bitLength(result.mantissa) == precision` for a non-zero result
## (every path ends in `normalize`/`normalizeRounded` or an early zero return).
## Per the recursion doctrine, ensures never call a contracted proc; `isZero`
## (BigFloat) is deliberately uncontracted so it may be used here. The
## division-by-zero guard is a body `raise` (domain-guard doctrine: it must
## survive `-d:release`).
import contracts
import big_float
import ../arithmetic

const DefaultPrecision* = 256

# Forward declarations: `*`/`+`/`-`/`/` delegate to the directed-rounding
# primitives (round-to-nearest is the default rounding for the operators).
func addRounded*(a, b: BigFloat, precision: int = DefaultPrecision,
                 mode: RoundingMode = rmNearest): BigFloat
func subRounded*(a, b: BigFloat, precision: int = DefaultPrecision,
                 mode: RoundingMode = rmNearest): BigFloat
func mulRounded*(a, b: BigFloat, precision: int = DefaultPrecision,
                 mode: RoundingMode = rmNearest): BigFloat
func divRounded*(a, b: BigFloat, precision: int = DefaultPrecision,
                 mode: RoundingMode = rmNearest): BigFloat

func operandPrecision(a, b: BigFloat): int {.inline.} =
  ## Cheap non-contracted witness for inferred-precision postconditions.
  max(if a.isZero: DefaultPrecision else: bitLength(a.mantissa),
      if b.isZero: DefaultPrecision else: bitLength(b.mantissa))

func `*`*(a, b: BigFloat, precision: int): BigFloat {.contractual.} =
  ## Multiplication, correctly rounded (round-to-nearest) via `mulRounded`.
  ensure:
    (a.isZero or b.isZero) == result.isZero
    result.isZero or result.sign == (a.sign != b.sign)
    result.isZero or bitLength(result.mantissa) == precision
  body:
    result = mulRounded(a, b, precision, rmNearest)

func `*`*(a, b: BigFloat): BigFloat {.contractual, inline.} =
  ensure:
    (a.isZero or b.isZero) == result.isZero
    result.isZero or result.sign == (a.sign != b.sign)
    result.isZero or bitLength(result.mantissa) == operandPrecision(a, b)
  body:
    mulRounded(a, b, operandPrecision(a, b), rmNearest)

func `+`*(a, b: BigFloat, precision: int): BigFloat {.contractual.} =
  ## Addition with round-to-nearest. Alignment is exact (left shift of the
  ## larger-exponent mantissa — no bit lost), rounding once at normalization.
  ensure:
    (not (a.isZero and b.isZero)) or result.isZero
    result.isZero or bitLength(result.mantissa) == precision
  body:
    addRounded(a, b, precision, rmNearest)

func `+`*(a, b: BigFloat): BigFloat {.contractual, inline.} =
  ensure:
    (not (a.isZero and b.isZero)) or result.isZero
    result.isZero or bitLength(result.mantissa) == operandPrecision(a, b)
  body:
    addRounded(a, b, operandPrecision(a, b), rmNearest)

func `-`*(a, b: BigFloat, precision: int): BigFloat {.contractual.} =
  ## Subtraction with round-to-nearest (see `+`).
  ensure:
    (not (a.isZero and b.isZero)) or result.isZero
    result.isZero or bitLength(result.mantissa) == precision
  body:
    subRounded(a, b, precision, rmNearest)

func `-`*(a, b: BigFloat): BigFloat {.contractual, inline.} =
  ensure:
    (not (a.isZero and b.isZero)) or result.isZero
    result.isZero or bitLength(result.mantissa) == operandPrecision(a, b)
  body:
    subRounded(a, b, operandPrecision(a, b), rmNearest)

func `-`*(a: BigFloat): BigFloat {.contractual.} =
  ## Unary negation. Zero is preserved (and stays non-negative).
  ensure:
    result.isZero == a.isZero
  body:
    result = a
    if not isZero(a):
      result.sign = not a.sign

func abs*(a: BigFloat): BigFloat {.contractual.} =
  ## Absolute value: non-negative, preserves zero-ness.
  ensure:
    not result.sign
    result.isZero == a.isZero
  body:
    result = a
    result.sign = false

func `/`*(a, b: BigFloat, precision: int): BigFloat {.contractual.} =
  ## Division, correctly rounded (round-to-nearest) via `divRounded` (guard +
  ## sticky remainder). Division by zero is a body `raise`.
  ensure:
    a.isZero == result.isZero
    result.isZero or result.sign == (a.sign != b.sign)
    result.isZero or bitLength(result.mantissa) == precision
  body:
    result = divRounded(a, b, precision, rmNearest)

func `/`*(a, b: BigFloat): BigFloat {.contractual, inline.} =
  ensure:
    a.isZero == result.isZero
    result.isZero or result.sign == (a.sign != b.sign)
    result.isZero or bitLength(result.mantissa) == operandPrecision(a, b)
  body:
    divRounded(a, b, operandPrecision(a, b), rmNearest)

# Directed-rounding operations. `rmUp` returns a bound >= the exact result,
# `rmDown` a bound <=; `rmNearest`/`rmTrunc` are faithful to 1 ulp on the
# sticky paths (negligible operand, division remainder) — see `normalizeRounded`.

const stickyGapBits = 64
  ## Beyond `precision + stickyGapBits` of exponent gap, the aligned operand
  ## only affects the result through a sticky bit.

func addRounded*(a, b: BigFloat, precision: int = DefaultPrecision,
                 mode: RoundingMode = rmNearest): BigFloat {.contractual.} =
  ## Directed-rounding addition. Alignment is exact (left shift of the operand
  ## with the larger exponent): no bit is lost before the final rounding, except
  ## on the sticky path. A non-zero result is normalized to `precision` bits.
  ensure:
    result.isZero or bitLength(result.mantissa) == precision
  body:
    if a.isZero:
      result = b
      result.normalizeRounded(precision, mode)
      return
    if b.isZero:
      result = a
      result.normalizeRounded(precision, mode)
      return
    if a.exponent < b.exponent:
      return addRounded(b, a, precision, mode)

    let expDiff = a.exponent - b.exponent
    if expDiff > int64(precision + stickyGapBits):
      # b sits entirely below the ulp of the result: sticky path. The bump
      # direction is reasoned toward +/-infinity, not in magnitude.
      result = a
      result.normalizeRounded(precision, mode)
      let contribPositive = not b.sign
      if mode == rmUp and contribPositive:
        if not result.sign: bumpMagnitude(result, precision)
        else: dropMagnitude(result, precision)
      elif mode == rmDown and not contribPositive:
        if not result.sign: dropMagnitude(result, precision)
        else: bumpMagnitude(result, precision)
      return

    # Exact alignment: lift the mantissa of a to the scale of b.
    let maAligned = a.mantissa shl Natural(int(expDiff))
    if a.sign == b.sign:
      result.mantissa = maAligned + b.mantissa
      result.sign = a.sign
    else:
      if maAligned >= b.mantissa:
        result.mantissa = maAligned - b.mantissa
        result.sign = a.sign
      else:
        result.mantissa = b.mantissa - maAligned
        result.sign = b.sign
    result.exponent = b.exponent
    if isZero(result.mantissa):
      result.sign = false
      result.exponent = 0
      return
    result.normalizeRounded(precision, mode)
    result

func subRounded*(a, b: BigFloat, precision: int = DefaultPrecision,
                 mode: RoundingMode = rmNearest): BigFloat {.contractual.} =
  ## Directed-rounding subtraction (`a - b`).
  ensure:
    result.isZero or bitLength(result.mantissa) == precision
  body:
    var negB = b
    if not isZero(negB):
      negB.sign = not b.sign
    addRounded(a, negB, precision, mode)

func mulRounded*(a, b: BigFloat, precision: int = DefaultPrecision,
                 mode: RoundingMode = rmNearest): BigFloat {.contractual.} =
  ## Directed-rounding multiplication. The mantissa product is exact; rounding
  ## only happens at the final normalization.
  ensure:
    (a.isZero or b.isZero) == result.isZero
    result.isZero or result.sign == (a.sign != b.sign)
    result.isZero or bitLength(result.mantissa) == precision
  body:
    if a.isZero or b.isZero:
      return BigFloat(mantissa: initBigUInt(0'u64))
    result.sign = a.sign != b.sign
    result.exponent = a.exponent + b.exponent
    result.mantissa = a.mantissa * b.mantissa
    result.normalizeRounded(precision, mode)
    result

func divRounded*(a, b: BigFloat, precision: int = DefaultPrecision,
                 mode: RoundingMode = rmNearest): BigFloat {.contractual.} =
  ## Directed-rounding division: 2 guard bits + sticky remainder. Division by
  ## zero is a body `raise`.
  ensure:
    a.isZero == result.isZero
    result.isZero or result.sign == (a.sign != b.sign)
    result.isZero or bitLength(result.mantissa) == precision
  body:
    if b.isZero: raise newException(DivByZeroDefect, "BigFloat division by zero")
    if a.isZero: return a
    result.sign = a.sign != b.sign
    let guard = precision + 2
    let maShifted = a.mantissa shl Natural(guard)
    let bm = b.mantissa
    # Fast path: a divisor whose value fits in one Limb has a normalized
    # mantissa that is nonzero only in the top limb (the low limbs are zero).
    # That is the Taylor-denominator case (a small integer padded to full
    # width). Divide by the single significant limb with `divModLimb` (Knuth
    # §4.3.1 single-limb long division) instead of the general multi-limb
    # `divMod`, and fold the implicit limb shift into the exponent.
    var sticky = false
    var fast = bm.limbs.len > 1
    if fast:
      for i in 0 ..< bm.limbs.high:
        if bm.limbs[i] != ZeroLimb:
          fast = false
          break
    if fast:
      let topLimb = bm.limbs[bm.limbs.high]
      let d = topLimb shr clzLimb(topLimb)
      let bmShift = clzLimb(topLimb) + LimbBits * (bm.limbs.len - 1)
      let (q, r) = divModLimb(maShifted, d)
      result.mantissa = q
      result.exponent = (a.exponent - b.exponent) - int64(guard) - int64(bmShift)
      sticky = r != ZeroLimb
    else:
      let (q, r) = divMod(maShifted, bm)
      result.mantissa = q
      result.exponent = (a.exponent - b.exponent) - int64(guard)
      sticky = not isZero(r)
    result.normalizeRounded(precision, mode, sticky)
    result
