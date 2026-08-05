# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Arbitrary-precision floating point. A `BigFloat` is `mantissa * 2^exponent`
## with a `sign` flag; the mantissa is a `BigUInt` normalized to `precision`
## bits (top bit set) or zero. Inf/NaN are not representable (a finite type).
import contracts
import std/math
import ../arithmetic

const float64SigBits* = 53 ## float64 significand bits (implicit-1 + 52 stored)

type
  BigFloat* = object
    sign*: bool
    exponent*: int64
    mantissa*: BigUInt

  RoundingMode* = enum
    ## Rounding mode for normalization and directed operations.
    rmNearest ## to nearest — halfway rounds away from zero (no round-to-even)
    rmTrunc   ## toward zero (same rounding as `normalize`)
    rmUp      ## toward +infinity
    rmDown    ## toward -infinity

func isZero*(a: BigFloat): bool {.inline.} =
  ## Zero test. Defined before the constructors and mutators so it is visible
  ## in their `ensure` blocks. Deliberately uncontracted so it may be used in
  ## other procs' ensures (recursion doctrine).
  isZero(a.mantissa)

func normalize*(a: var BigFloat, precision: int = 256) {.contractual.} =
  ## Normalize the mantissa to exactly `precision` bits (top bit set), or zero.
  ## The `ensure` uses only the uncontracted `isZero`/`bitLength` witnesses
  ## (recursion doctrine).
  ensure:
    a.isZero or bitLength(a.mantissa) == precision
  body:
    if isZero(a.mantissa):
      a.exponent = 0
      return
    let currentBits = bitLength(a.mantissa)
    if currentBits > precision:
      let shift = currentBits - precision
      a.mantissa = a.mantissa shr Natural(shift)
      a.exponent += int64(shift)
    elif currentBits < precision and currentBits > 0:
      let shift = precision - currentBits
      a.mantissa = a.mantissa shl Natural(shift)
      a.exponent -= int64(shift)

func fromBigInt*(val: BigInt, precision: int = 256): BigFloat {.contractual.} =
  ## Build from a `BigInt`, normalized to `precision` bits.
  ensure:
    result.isZero == val.isZero
    result.isZero or result.sign == val.isNegative
  body:
    result.sign = val.isNegative
    result.mantissa = val.mag
    result.exponent = 0
    result.normalize(precision)
    result

func initBigFloat*(val: float64, precision: int = 256): BigFloat {.contractual.} =
  ## Build from a float64, normalized to `precision` bits. ±Inf and NaN are not
  ## representable and raise `ValueError`.
  ensure:
    result.isZero == (val == 0.0)
    result.isZero or result.sign == (val < 0.0)
  body:
    if val == 0.0:
      return BigFloat(sign: false, exponent: 0, mantissa: initBigUInt(0))
    if classify(val) in {fcInf, fcNegInf, fcNan}:
      raise newException(ValueError, "initBigFloat: Inf/NaN are not representable")
    result.sign = val < 0
    var v = abs(val)
    var exp: int64 = 0
    if v >= 1.0:
      while v >= 2.0:
        v /= 2.0
        exp += 1
    else:
      while v < 1.0 and v > 0.0:
        v *= 2.0
        exp -= 1
    # v is now in [1.0, 2.0); extract up to 53 bits (float64 carries 53).
    let extractBits = min(precision, float64SigBits)
    let scale = pow(2.0, float64(extractBits - 1))
    result.mantissa = initBigUInt(uint64(v * scale))
    result.exponent = exp - int64(extractBits - 1)
    result.normalize(precision)
    result

func bumpMagnitude*(a: var BigFloat, precision: int) {.contractual.} =
  ## Representable successor in magnitude: +1 ulp, renormalize on overflow.
  ensure:
    a.isZero or bitLength(a.mantissa) == precision
  body:
    a.mantissa = a.mantissa + initBigUInt(1'u64)
    if bitLength(a.mantissa) > precision:
      a.mantissa = a.mantissa shr Natural(1)
      a.exponent += 1

func dropMagnitude*(a: var BigFloat, precision: int) {.contractual.} =
  ## Representable predecessor in magnitude: -1 ulp, re-shift at the power-of-
  ## two edge so the low bit stays set.
  ensure:
    a.isZero or bitLength(a.mantissa) == precision
  body:
    if isZero(a.mantissa):
      return
    a.mantissa = a.mantissa - initBigUInt(1'u64)
    if not isZero(a.mantissa) and bitLength(a.mantissa) < precision:
      a.mantissa = (a.mantissa shl Natural(1)) or initBigUInt(1'u64)
      a.exponent -= 1

func normalizeRounded*(a: var BigFloat, precision: int, mode: RoundingMode,
                       sticky: bool = false) {.contractual.} =
  ## Normalize to `precision` bits with directed rounding. `sticky` signals
  ## that non-zero bits of the mantissa's sign were already lost upstream
  ## (division remainder, operand below the ulp). `rmUp` bounds above the exact
  ## value, `rmDown` below; `rmNearest` rounds to nearest (halfway away from
  ## zero); `rmTrunc` truncates the magnitude. The `ensure` uses only
  ## uncontracted `isZero`/`bitLength`; the body calls the contracted
  ## `bumpMagnitude` (doctrine: bodies may call contracted procs).
  ensure:
    a.isZero or bitLength(a.mantissa) == precision
  body:
    if isZero(a.mantissa):
      a.exponent = 0
      return
    let currentBits = bitLength(a.mantissa)
    if currentBits > precision:
      let shift = currentBits - precision
      # Round/sticky from the low `shift` bits by limb inspection, not by
      # building `mask`/`dropped`/`half` BigUInts (this runs after every
      # BigFloat mul/add/div, so those allocations dominated transcendental
      # cost). The round bit is bit `shift-1`; the dropped tail is the low
      # `shift` bits. `rmNearest` is halfway-away, so round up iff the round
      # bit is set (equivalent to the old `dropped >= half`, since
      # `dropped < 2^shift`); `rmUp`/`rmDown` round up iff any dropped bit or
      # the upstream `sticky` flag is set.
      let rLimb = (shift - 1) div LimbBits
      let rBit = (shift - 1) mod LimbBits
      let roundSet = rLimb < a.mantissa.limbs.len and
                     ((a.mantissa.limbs[rLimb] shr rBit) and 1'u64) != 0
      var tailNonZero = sticky
      if not tailNonZero:
        let fullLimbs = shift div LimbBits
        var i = 0
        let hi = min(fullLimbs, a.mantissa.limbs.len)
        while i < hi and not tailNonZero:
          if a.mantissa.limbs[i] != ZeroLimb: tailNonZero = true
          inc i
        if not tailNonZero:
          let partial = shift mod LimbBits
          if partial > 0 and fullLimbs < a.mantissa.limbs.len:
            let lowMask = (Limb(1) shl partial) - 1
            if (a.mantissa.limbs[fullLimbs] and lowMask) != ZeroLimb:
              tailNonZero = true
      # In-place right shift by `shift` bits (no fresh `seq`): drop whole
      # limbs, then shift the remainder down with the high neighbour -- the
      # same algorithm as `BigUInt.shr`, just without the new `newSeq`. The
      # source limbs [w, n) are read before the low slots [0, n-w) they fill
      # are overwritten, so the in-place copy is safe.
      let w = shift div LimbBits
      let partial = shift mod LimbBits
      if w > 0:
        let n = a.mantissa.limbs.len
        for i in 0 ..< n - w:
          a.mantissa.limbs[i] = a.mantissa.limbs[i + w]
        a.mantissa.limbs.setLen(n - w)
      if partial > 0 and a.mantissa.limbs.len > 0:
        let n = a.mantissa.limbs.len
        for i in 0 ..< n - 1:
          a.mantissa.limbs[i] = (a.mantissa.limbs[i] shr partial) or
                                (a.mantissa.limbs[i + 1] shl (LimbBits - partial))
        a.mantissa.limbs[n - 1] = a.mantissa.limbs[n - 1] shr partial
      a.mantissa.trim()
      a.exponent += int64(shift)
      let lost = tailNonZero
      let roundMagUp =
        case mode
        of rmTrunc: false
        of rmUp: (not a.sign) and lost
        of rmDown: a.sign and lost
        of rmNearest: roundSet
      if roundMagUp:
        bumpMagnitude(a, precision)
    else:
      if currentBits < precision:
        let shift = precision - currentBits
        a.mantissa = a.mantissa shl Natural(shift)
        a.exponent -= int64(shift)
      if sticky and ((mode == rmUp and not a.sign) or (mode == rmDown and a.sign)):
        bumpMagnitude(a, precision)

# Concept construction: `fromInt(BigFloat, n)` / `fromFloat(BigFloat, f)` build
# a default-precision (256-bit) BigFloat so generic series bounded by `Field`
# can build coefficients without an injected constructor.
func fromInt*(T: typedesc[BigFloat], v: int): BigFloat {.inline.} =
  initBigFloat(float64(v))

func fromFloat*(T: typedesc[BigFloat], v: float64): BigFloat {.inline.} =
  initBigFloat(v)

# Opt-in narrowing converters (`BigFloat(2.0)`, `BigFloat(2)`). The canonical
# direction is the explicit `initBigFloat`; implicit conversions across
# packages collide, so they are gated by `-d:umConverters`.
when defined(umConverters):
  converter toBigFloat*(val: float64): BigFloat =
    initBigFloat(val)
  converter toBigFloat*(val: int): BigFloat =
    initBigFloat(float64(val))
