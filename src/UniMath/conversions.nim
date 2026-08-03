# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Cross-type conversions completing the matrix between the numeric backends:
## float64, BigInt, Fixed, Rational, BigFloat, Interval. Each proc documents its
## exactness contract — "exact" (no loss, or an explicit exception), "rounded"
## (controlled loss via a selectable rounding mode), or "enclosure" (an interval
## guaranteed to contain the source value).
##
## Conversions already provided by the base packages (`toFloat64` everywhere,
## `initBigFloat`, `fromBigInt`, `toFixed` from int/float, `initRational`) are
## not duplicated here.
##
## Contracts (NimContracts): the public procs carry `{.contractual.}` + `body:`
## only — no inline `ensure`. A rounding/exactness/enclosure postcondition would
## need a cross-type comparison delegating to the contracted `cmp`/`div` of
## BigInt/Fixed/Rational/BigFloat (recursion doctrine: an `ensure` may not call
## the contracted witnesses). The identities are documented per-proc and
## verified externally by `test_conversions`. Domain guards (NaN/Inf,
## int64/representation overflow) are body `raise`s that survive release.

import std/math
import contracts
import ./arithmetic
import ./fixed
import ./float
import ./rational
import ./interval

# ------------------------------------------------------------------------------
# float64 -> Rational (exact)
# ------------------------------------------------------------------------------

func decomposeFloat(val: float64): (int64, int) =
  ## Decomposes a finite non-zero float64 into (m, e) with `val == m * 2^e`,
  ## `m` an integer on <= 53 bits, reduced (m odd).
  let (frac, exp) = frexp(val)
  # frac is in [0.5, 1), exactly representable on 53 bits.
  var m = int64(abs(frac) * pow(2.0, 53'f64))
  var e = exp - 53
  # strip trailing zero bits to minimize |e|
  while m != 0 and (m and 1) == 0:
    m = m shr 1
    inc e
  if val < 0: m = -m
  (m, e)

func toRationalExact*(val: float64): Rational[int64] {.contractual.} =
  ## EXACT conversion float64 -> Rational[int64]. Every finite float64 is exactly
  ## `m * 2^e`; the fraction is `m / 2^-e`. Raises `ValueError` on NaN/Inf, or
  ## when the exponent overflows int64 (`|e| > 62` after reduction) — use
  ## `toRationalBig` in that case.
  body:
    if val != val or abs(val) == Inf:
      raise newException(ValueError, "toRationalExact: NaN or infinity")
    if val == 0.0:
      return initRational(0'i64, 1'i64)
    let (m, e) = decomposeFloat(val)
    if e >= 0:
      if e > 62 or abs(m) > (high(int64) shr e):
        raise newException(ValueError,
          "toRationalExact: int64 overflow (use toRationalBig)")
      result = initRational(m shl e, 1'i64)
    else:
      if -e > 62:
        raise newException(ValueError,
          "toRationalExact: denominator > 2^62 (use toRationalBig)")
      result = initRational(m, 1'i64 shl (-e))

func toRationalBig*(val: float64): Rational[BigInt] {.contractual.} =
  ## EXACT conversion float64 -> Rational[BigInt], with no exponent limit
  ## (covers subnormals and very large exponents). Raises `ValueError` on
  ## NaN/Inf.
  body:
    if val != val or abs(val) == Inf:
      raise newException(ValueError, "toRationalBig: NaN or infinity")
    if val == 0.0:
      return initRational(initBigInt(0), initBigInt(1))
    let (m, e) = decomposeFloat(val)
    let mag = initBigUInt(uint64(abs(m)))
    if e >= 0:
      result = initRational(initBigInt(mag shl Natural(e), m < 0),
                            initBigInt(1))
    else:
      result = initRational(initBigInt(mag, m < 0),
                            initBigInt(initBigUInt(1'u64) shl Natural(-e)))

# ------------------------------------------------------------------------------
# Fixed -> Rational (exact)
# ------------------------------------------------------------------------------

func toRational*[T; FracBits: static[int]](
    a: Fixed[T, FracBits]): Rational[int64] {.contractual.} =
  ## EXACT conversion Fixed -> Rational[int64]: value = `data / 2^FracBits`.
  ## `initRational` reduces the fraction (gcd).
  body:
    static: doAssert FracBits <= 62, "FracBits > 62: denominator exceeds int64"
    initRational(int64(a.data), 1'i64 shl FracBits)

# ------------------------------------------------------------------------------
# Rational / Fixed -> BigFloat
# ------------------------------------------------------------------------------

func toBigFloat*(a: Rational[int64]; precision: int = 256;
                 mode: RoundingMode = rmNearest): BigFloat {.contractual.} =
  ## ROUNDED conversion Rational -> BigFloat (directed num/den division).
  ## `rmUp`/`rmDown` yield guaranteed bounds — the basis for enclosures.
  body:
    let numBF = fromBigInt(initBigInt(a.num), precision)
    let denBF = fromBigInt(initBigInt(a.den), precision)
    divRounded(numBF, denBF, precision, mode)

func toBigFloat*(a: Rational[BigInt]; precision: int = 256;
                 mode: RoundingMode = rmNearest): BigFloat {.contractual.} =
  ## ROUNDED conversion `Rational[BigInt]` -> BigFloat (directed num/den
  ## division). The unbounded backend — the C ABI rational handle path.
  body:
    let numBF = fromBigInt(a.num, precision)
    let denBF = fromBigInt(a.den, precision)
    divRounded(numBF, denBF, precision, mode)

func toBigFloat*[T; FracBits: static[int]](a: Fixed[T, FracBits];
    precision: int = 256): BigFloat {.contractual.} =
  ## EXACT conversion Fixed -> BigFloat: `data * 2^-FracBits` (a plain exponent
  ## adjustment, no loss). `data` is widened to BigInt without an int64
  ## round-trip, so `Fixed[BigInt, _]` keeps full precision.
  body:
    when T is BigInt:
      result = fromBigInt(a.data, precision)
    else:
      result = fromBigInt(initBigInt(int64(a.data)), precision)
    if not isZero(result):
      result.exponent -= int64(FracBits)

# ------------------------------------------------------------------------------
# BigFloat / Rational -> BigInt (truncation)
# ------------------------------------------------------------------------------

func toBigInt*(a: BigFloat): BigInt {.contractual.} =
  ## TRUNCATED (toward zero) conversion BigFloat -> BigInt.
  body:
    if isZero(a):
      return initBigInt(0)
    if a.exponent >= 0:
      initBigInt(a.mantissa shl int(a.exponent), a.sign)
    else:
      let shifted = a.mantissa shr int(-a.exponent)
      initBigInt(shifted, a.sign and not isZero(shifted))

func toBigInt*(a: Rational[int64]): BigInt {.contractual.} =
  ## TRUNCATED (toward zero) conversion Rational -> BigInt.
  body:
    initBigInt(a.num div a.den)

func toBigInt*(a: Rational[BigInt]): BigInt {.contractual.} =
  ## TRUNCATED (toward zero) conversion `Rational[BigInt]` -> BigInt — the
  ## unbounded backend (C ABI rational handle path). `BigInt.div` truncates
  ## toward zero, matching the `int64` overload.
  body:
    a.num div a.den

# ------------------------------------------------------------------------------
# Rational / BigFloat -> Fixed
# ------------------------------------------------------------------------------

func toFixed*[T; FracBits: static[int]](
    a: Rational[int64]): Fixed[T, FracBits] {.contractual.} =
  ## TRUNCATED conversion Rational -> Fixed: `data = (num * 2^FracBits) div den`.
  ## The intermediate product goes through BigUInt (no hidden overflow). Raises
  ## `ValueError` when the result does not fit in 63 bits.
  body:
    let negative = (a.num < 0) != (a.den < 0)
    let numMag = initBigUInt(uint64(abs(a.num))) shl Natural(FracBits)
    let denMag = initBigUInt(uint64(abs(a.den)))
    let q = numMag div denMag
    if bitLength(q) > 63:
      raise newException(ValueError, "toFixed: representation overflow")
    var raw = if isZero(q): 0'i64 else: int64(q.limbs[0])
    if negative: raw = -raw
    initFixed[T, FracBits](T(raw))

func toFixed*[T; FracBits: static[int]](
    a: BigFloat): Fixed[T, FracBits] {.contractual.} =
  ## TRUNCATED conversion BigFloat -> Fixed: aligns the mantissa onto the
  ## `2^-FracBits` grid. Raises `ValueError` on overflow.
  body:
    var scaled = a
    scaled.exponent += int64(FracBits)
    let big = toBigInt(scaled)
    if bitLength(big.mag) > 63:
      raise newException(ValueError, "toFixed: representation overflow")
    var raw = if isZero(big.mag): 0'i64 else: int64(big.mag.limbs[0])
    if big.isNegative: raw = -raw
    initFixed[T, FracBits](T(raw))

# ------------------------------------------------------------------------------
# -> Interval (enclosures)
# ------------------------------------------------------------------------------
# toFloat64 performs 1 to 2 roundings depending on the source type; widening by
# 2 nextUp/nextDown steps on each side guarantees the enclosure.

func widen2(f: float64): Interval[float64] {.inline.} =
  initInterval(nextDown(nextDown(f)), nextUp(nextUp(f)))

func toInterval*[T](a: Rational[T]): Interval[float64] {.contractual.} =
  ## ENCLOSURE of the exact value `num/den` (toFloat64 = at most 2 roundings).
  body:
    widen2(toFloat64(a))

func toInterval*(a: BigFloat): Interval[float64] {.contractual.} =
  ## ENCLOSURE of the exact value `mantissa * 2^exponent`.
  body:
    widen2(toFloat64(a))

func toInterval*[T; FracBits: static[int]](
    a: Fixed[T, FracBits]): Interval[float64] {.contractual.} =
  ## ENCLOSURE of the exact value `data * 2^-FracBits`.
  body:
    widen2(toFloat64(a))

func toInterval*(a: BigInt): Interval[float64] {.contractual.} =
  ## ENCLOSURE of a big integer (toFloat64 truncates beyond 53 bits).
  body:
    widen2(toFloat64(a))
